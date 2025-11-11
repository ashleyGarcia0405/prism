# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/services/mpc_query_parser'
require_relative '../../app/services/where_clause_builder'

RSpec.describe MPCQueryParser do
  let(:organization) { Organization.create!(name: "Test Org") }
  let(:dataset) do
    Dataset.create!(
      name: "Test Dataset",
      organization: organization,
      table_name: "test_mpc_patients"
    )
  end

  before do
    # Create test table
    ActiveRecord::Base.connection.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS test_mpc_patients (
        id SERIAL PRIMARY KEY,
        age INTEGER,
        salary DECIMAL(10,2),
        name VARCHAR(255),
        diagnosis TEXT,
        state VARCHAR(2)
      )
    SQL
  end

  after do
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS test_mpc_patients")
  end

  describe '#column_name' do
    it 'extracts column name from string key' do
      parser = MPCQueryParser.new({ 'column' => 'age' })
      expect(parser.column_name).to eq('age')
    end

    it 'extracts column name from symbol key' do
      parser = MPCQueryParser.new({ column: 'salary' })
      expect(parser.column_name).to eq('salary')
    end

    it 'returns nil when column not specified' do
      parser = MPCQueryParser.new({})
      expect(parser.column_name).to be_nil
    end
  end

  describe '#query_type' do
    it 'extracts query type from string key' do
      parser = MPCQueryParser.new({ 'query_type' => 'sum' })
      expect(parser.query_type).to eq('sum')
    end

    it 'extracts query type from symbol key' do
      parser = MPCQueryParser.new({ query_type: 'count' })
      expect(parser.query_type).to eq('count')
    end

    it 'converts query type to lowercase' do
      parser = MPCQueryParser.new({ 'query_type' => 'SUM' })
      expect(parser.query_type).to eq('sum')
    end

    it 'returns nil when query type not specified' do
      parser = MPCQueryParser.new({})
      expect(parser.query_type).to be_nil
    end
  end

  describe '#where_conditions' do
    it 'extracts where conditions from string key' do
      conditions = { 'age' => 30 }
      parser = MPCQueryParser.new({ 'where' => conditions })
      expect(parser.where_conditions).to eq(conditions)
    end

    it 'extracts where conditions from symbol key' do
      conditions = { age: 30 }
      parser = MPCQueryParser.new({ where: conditions })
      expect(parser.where_conditions).to eq(conditions)
    end

    it 'returns empty hash when where not specified' do
      parser = MPCQueryParser.new({})
      expect(parser.where_conditions).to eq({})
    end
  end

  describe '#valid_query_params?' do
    context 'with valid parameters' do
      it 'validates sum query' do
        parser = MPCQueryParser.new({
          'query_type' => 'sum',
          'column' => 'age'
        })

        result = parser.valid_query_params?
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end

      it 'validates count query without column' do
        parser = MPCQueryParser.new({
          'query_type' => 'count'
        })

        result = parser.valid_query_params?
        expect(result[:valid]).to be true
      end

      it 'validates avg query' do
        parser = MPCQueryParser.new({
          'query_type' => 'avg',
          'column' => 'salary'
        })

        result = parser.valid_query_params?
        expect(result[:valid]).to be true
      end

      it 'validates query with where conditions' do
        parser = MPCQueryParser.new({
          'query_type' => 'sum',
          'column' => 'age',
          'where' => { 'state' => 'CA' }
        })

        result = parser.valid_query_params?
        expect(result[:valid]).to be true
      end
    end

    context 'with invalid query type' do
      it 'rejects unknown query type' do
        parser = MPCQueryParser.new({
          'query_type' => 'median',
          'column' => 'age'
        })

        result = parser.valid_query_params?
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(match(/Invalid query_type/))
      end

      it 'rejects nil query type' do
        parser = MPCQueryParser.new({
          'column' => 'age'
        })

        result = parser.valid_query_params?
        expect(result[:valid]).to be false
      end
    end

    context 'with missing column' do
      it 'rejects sum query without column' do
        parser = MPCQueryParser.new({
          'query_type' => 'sum'
        })

        result = parser.valid_query_params?
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(match(/Column name is required/))
      end

      it 'rejects avg query without column' do
        parser = MPCQueryParser.new({
          'query_type' => 'avg'
        })

        result = parser.valid_query_params?
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(match(/Column name is required/))
      end
    end

    context 'with invalid where conditions' do
      it 'rejects non-hash where conditions' do
        parser = MPCQueryParser.new({
          'query_type' => 'sum',
          'column' => 'age',
          'where' => 'invalid'
        })

        result = parser.valid_query_params?
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(match(/Invalid WHERE conditions/))
      end
    end
  end

  describe '#valid_where_conditions?' do
    context 'with valid conditions' do
      it 'allows simple equality conditions' do
        parser = MPCQueryParser.new({
          'where' => { 'state' => 'CA', 'age' => 30 }
        })

        expect(parser.valid_where_conditions?).to be true
      end

      it 'allows array values for IN clauses' do
        parser = MPCQueryParser.new({
          'where' => { 'state' => ['CA', 'NY', 'TX'] }
        })

        expect(parser.valid_where_conditions?).to be true
      end

      it 'allows complex conditions with operators' do
        parser = MPCQueryParser.new({
          'where' => {
            'age' => { 'operator' => 'between', 'min' => 20, 'max' => 65 }
          }
        })

        expect(parser.valid_where_conditions?).to be true
      end

      it 'allows nil values' do
        parser = MPCQueryParser.new({
          'where' => { 'diagnosis' => nil }
        })

        expect(parser.valid_where_conditions?).to be true
      end

      it 'allows boolean values' do
        parser = MPCQueryParser.new({
          'where' => { 'active' => true }
        })

        expect(parser.valid_where_conditions?).to be true
      end
    end

    context 'with invalid conditions' do
      it 'rejects non-hash conditions' do
        parser = MPCQueryParser.new({
          'where' => 'invalid'
        })

        expect(parser.valid_where_conditions?).to be false
      end

      it 'rejects array with non-scalar values' do
        parser = MPCQueryParser.new({
          'where' => { 'state' => [{ 'complex' => 'object' }] }
        })

        expect(parser.valid_where_conditions?).to be false
      end

      it 'rejects complex hash conditions with invalid operators' do
        parser = MPCQueryParser.new({
          'where' => {
            'age' => { 'operator' => 'invalid_op', 'value' => 30 }
          }
        })

        expect(parser.valid_where_conditions?).to be false
      end
    end

    context 'with empty conditions' do
      it 'allows empty where clause' do
        parser = MPCQueryParser.new({})
        expect(parser.valid_where_conditions?).to be true
      end
    end
  end

  describe '#build_sql_for_dataset' do
    context 'for sum queries' do
      it 'builds sum query without where clause' do
        parser = MPCQueryParser.new({
          'query_type' => 'sum',
          'column' => 'age'
        })

        sql = parser.build_sql_for_dataset(dataset)
        expect(sql).to include('SELECT SUM')
        expect(sql).to include('age')
        expect(sql).to include(dataset.table_quoted)
      end

      it 'builds sum query with where clause' do
        parser = MPCQueryParser.new({
          'query_type' => 'sum',
          'column' => 'salary',
          'where' => { 'state' => 'CA' }
        })

        sql = parser.build_sql_for_dataset(dataset)
        expect(sql).to include('SELECT SUM')
        expect(sql).to include('salary')
        expect(sql).to include('WHERE')
      end
    end

    context 'for count queries' do
      it 'builds count query without where clause' do
        parser = MPCQueryParser.new({
          'query_type' => 'count'
        })

        sql = parser.build_sql_for_dataset(dataset)
        expect(sql).to include('SELECT COUNT(*)')
        expect(sql).to include(dataset.table_quoted)
      end

      it 'builds count query with where clause' do
        parser = MPCQueryParser.new({
          'query_type' => 'count',
          'where' => { 'age' => { 'operator' => 'gte', 'value' => 18 } }
        })

        sql = parser.build_sql_for_dataset(dataset)
        expect(sql).to include('COUNT(*)')
        expect(sql).to include('WHERE')
      end
    end

    context 'for avg queries' do
      it 'builds sum query for avg (MPC computes average from sums)' do
        parser = MPCQueryParser.new({
          'query_type' => 'avg',
          'column' => 'age'
        })

        sql = parser.build_sql_for_dataset(dataset)
        # For AVG in MPC, we compute SUM locally
        expect(sql).to include('SELECT SUM')
        expect(sql).to include('age')
      end
    end

    context 'with unsupported query type' do
      it 'raises error' do
        parser = MPCQueryParser.new({
          'query_type' => 'median',
          'column' => 'age'
        })

        expect {
          parser.build_sql_for_dataset(dataset)
        }.to raise_error(/Unsupported query type/)
      end
    end
  end

  describe '#referenced_columns' do
    it 'includes main column' do
      parser = MPCQueryParser.new({
        'query_type' => 'sum',
        'column' => 'age'
      })

      expect(parser.referenced_columns).to include('age')
    end

    it 'includes where clause columns' do
      parser = MPCQueryParser.new({
        'query_type' => 'sum',
        'column' => 'salary',
        'where' => { 'state' => 'CA', 'age' => 30 }
      })

      columns = parser.referenced_columns
      expect(columns).to include('salary', 'state', 'age')
    end

    it 'returns unique columns' do
      parser = MPCQueryParser.new({
        'query_type' => 'sum',
        'column' => 'age',
        'where' => { 'age' => { 'operator' => 'gte', 'value' => 18 } }
      })

      columns = parser.referenced_columns
      expect(columns.count('age')).to eq(1)
    end

    it 'handles count queries without main column' do
      parser = MPCQueryParser.new({
        'query_type' => 'count',
        'where' => { 'state' => 'CA' }
      })

      columns = parser.referenced_columns
      expect(columns).to eq(['state'])
    end
  end

  describe '#validate_for_dataset' do
    context 'with valid query' do
      it 'validates sum query on numeric column' do
        parser = MPCQueryParser.new({
          'query_type' => 'sum',
          'column' => 'age'
        })

        result = parser.validate_for_dataset(dataset)
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end

      it 'validates count query' do
        parser = MPCQueryParser.new({
          'query_type' => 'count',
          'where' => { 'state' => 'CA' }
        })

        result = parser.validate_for_dataset(dataset)
        expect(result[:valid]).to be true
      end

      it 'validates avg query on numeric column' do
        parser = MPCQueryParser.new({
          'query_type' => 'avg',
          'column' => 'salary'
        })

        result = parser.validate_for_dataset(dataset)
        expect(result[:valid]).to be true
      end
    end

    context 'with missing columns' do
      it 'rejects query with non-existent main column' do
        parser = MPCQueryParser.new({
          'query_type' => 'sum',
          'column' => 'non_existent'
        })

        result = parser.validate_for_dataset(dataset)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(match(/not found/))
      end

      it 'rejects query with non-existent where column' do
        parser = MPCQueryParser.new({
          'query_type' => 'sum',
          'column' => 'age',
          'where' => { 'non_existent_column' => 'value' }
        })

        result = parser.validate_for_dataset(dataset)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(match(/not found/))
      end
    end

    context 'with wrong column type' do
      it 'rejects sum query on string column' do
        parser = MPCQueryParser.new({
          'query_type' => 'sum',
          'column' => 'name'
        })

        result = parser.validate_for_dataset(dataset)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(match(/must be numeric/))
      end

      it 'rejects avg query on string column' do
        parser = MPCQueryParser.new({
          'query_type' => 'avg',
          'column' => 'diagnosis'
        })

        result = parser.validate_for_dataset(dataset)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(match(/must be numeric/))
      end

      it 'allows count on any column type' do
        parser = MPCQueryParser.new({
          'query_type' => 'count',
          'where' => { 'name' => 'John' }
        })

        result = parser.validate_for_dataset(dataset)
        expect(result[:valid]).to be true
      end
    end
  end

  describe 'integration with WhereClauseBuilder' do
    it 'builds valid SQL with complex where conditions' do
      parser = MPCQueryParser.new({
        'query_type' => 'sum',
        'column' => 'salary',
        'where' => {
          'age' => { 'operator' => 'between', 'min' => 25, 'max' => 65 },
          'state' => ['CA', 'NY', 'TX']
        }
      })

      sql = parser.build_sql_for_dataset(dataset)

      expect(sql).to include('SUM')
      expect(sql).to include('salary')
      expect(sql).to include('WHERE')
      expect(sql).to include('BETWEEN')
      expect(sql).to include('IN')
    end

    it 'builds executable SQL' do
      # Insert test data
      ActiveRecord::Base.connection.execute(<<-SQL)
        INSERT INTO test_mpc_patients (age, salary, name, state)
        VALUES (30, 50000.00, 'John Doe', 'CA'),
               (40, 60000.00, 'Jane Smith', 'NY'),
               (25, 45000.00, 'Bob Johnson', 'TX')
      SQL

      parser = MPCQueryParser.new({
        'query_type' => 'sum',
        'column' => 'salary',
        'where' => { 'state' => 'CA' }
      })

      sql = parser.build_sql_for_dataset(dataset)
      result = ActiveRecord::Base.connection.execute(sql)

      expect(result.first['sum'].to_f).to eq(50000.00)

      # Clean up
      ActiveRecord::Base.connection.execute("DELETE FROM test_mpc_patients")
    end
  end

  describe 'edge cases' do
    it 'handles nil query params' do
      parser = MPCQueryParser.new(nil)

      expect(parser.column_name).to be_nil
      expect(parser.query_type).to be_nil
      expect(parser.where_conditions).to eq({})
    end

    it 'handles empty query params' do
      parser = MPCQueryParser.new({})

      result = parser.valid_query_params?
      expect(result[:valid]).to be false
    end

    it 'handles symbol and string keys interchangeably' do
      parser_string = MPCQueryParser.new({
        'query_type' => 'sum',
        'column' => 'age'
      })

      parser_symbol = MPCQueryParser.new({
        query_type: 'sum',
        column: 'age'
      })

      expect(parser_string.query_type).to eq(parser_symbol.query_type)
      expect(parser_string.column_name).to eq(parser_symbol.column_name)
    end
  end
end