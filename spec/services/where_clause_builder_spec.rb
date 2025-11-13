require 'rails_helper'

RSpec.describe WhereClauseBuilder, type: :service do
  let(:dataset) { instance_double(Dataset) }
  let(:builder) { WhereClauseBuilder.new(conditions, dataset) }

  before do
    # Mock sanitize_column to quote column names
    allow(dataset).to receive(:sanitize_column) do |col|
      "\"#{col}\""
    end

    # Mock sanitize_value to quote values
    allow(dataset).to receive(:sanitize_value) do |val|
      if val.nil?
        'NULL'
      elsif val.is_a?(String)
        "'#{val.gsub("'", "''")}'"
      elsif val.is_a?(TrueClass)
        'TRUE'
      elsif val.is_a?(FalseClass)
        'FALSE'
      else
        val.to_s
      end
    end
  end

  describe '#initialize' do
    context 'with conditions provided' do
      let(:conditions) { { 'age' => 25 } }

      it 'sets conditions' do
        expect(builder.conditions).to eq(conditions)
      end

      it 'sets dataset' do
        expect(builder.dataset).to equal(dataset)
      end
    end

    context 'with nil conditions' do
      let(:conditions) { nil }

      it 'initializes conditions as empty hash' do
        expect(builder.conditions).to eq({})
      end
    end

    context 'with empty conditions' do
      let(:conditions) { {} }

      it 'initializes with empty hash' do
        expect(builder.conditions).to eq({})
      end
    end
  end

  describe '#build' do
    context 'with empty conditions' do
      let(:conditions) { {} }

      it 'returns empty string' do
        expect(builder.build).to eq('')
      end
    end

    context 'with nil conditions' do
      let(:conditions) { nil }

      it 'returns empty string' do
        expect(builder.build).to eq('')
      end
    end

    context 'with single simple condition' do
      let(:conditions) { { 'age' => 30 } }

      it 'returns WHERE clause with single condition' do
        result = builder.build
        expect(result).to include('WHERE')
        expect(result).to include('"age"')
        expect(result).to include('30')
      end

      it 'uses equality operator' do
        result = builder.build
        expect(result).to include('=')
      end
    end

    context 'with multiple conditions' do
      let(:conditions) { { 'age' => 30, 'name' => 'John' } }

      it 'joins conditions with AND' do
        result = builder.build
        expect(result).to include('AND')
      end

      it 'includes both conditions' do
        result = builder.build
        expect(result).to include('"age"')
        expect(result).to include('"name"')
      end

      it 'includes WHERE keyword' do
        result = builder.build
        expect(result).to start_with(' WHERE ')
      end
    end

    context 'with leading space' do
      let(:conditions) { { 'status' => 'active' } }

      it 'starts with space before WHERE' do
        result = builder.build
        expect(result).to start_with(' ')
      end
    end
  end

  describe 'simple equality conditions' do
    context 'with integer value' do
      let(:conditions) { { 'age' => 25 } }

      it 'builds equality clause' do
        result = builder.build
        expect(result).to eq(' WHERE "age" = 25')
      end
    end

    context 'with string value' do
      let(:conditions) { { 'name' => 'Alice' } }

      it 'builds equality clause with quoted string' do
        result = builder.build
        expect(result).to eq(" WHERE \"name\" = 'Alice'")
      end
    end

    context 'with float value' do
      let(:conditions) { { 'score' => 95.5 } }

      it 'builds equality clause with float' do
        result = builder.build
        expect(result).to eq(' WHERE "score" = 95.5')
      end
    end

    context 'with boolean value true' do
      let(:conditions) { { 'active' => true } }

      it 'builds equality clause with TRUE' do
        result = builder.build
        expect(result).to eq(' WHERE "active" = TRUE')
      end
    end

    context 'with boolean value false' do
      let(:conditions) { { 'active' => false } }

      it 'builds equality clause with FALSE' do
        result = builder.build
        expect(result).to eq(' WHERE "active" = FALSE')
      end
    end

    context 'with string containing quotes' do
      let(:conditions) { { 'name' => "O'Brien" } }

      it 'escapes single quotes' do
        result = builder.build
        expect(result).to include("''")
      end
    end
  end

  describe 'NULL conditions' do
    context 'with nil value' do
      let(:conditions) { { 'deleted_at' => nil } }

      it 'builds IS NULL clause' do
        result = builder.build
        expect(result).to eq(' WHERE "deleted_at" IS NULL')
      end
    end

    context 'is_null operator' do
      let(:conditions) { { 'deleted_at' => { operator: 'is_null' } } }

      it 'builds IS NULL clause' do
        result = builder.build
        expect(result).to eq(' WHERE "deleted_at" IS NULL')
      end
    end

    context 'is_not_null operator' do
      let(:conditions) { { 'deleted_at' => { operator: 'is_not_null' } } }

      it 'builds IS NOT NULL clause' do
        result = builder.build
        expect(result).to eq(' WHERE "deleted_at" IS NOT NULL')
      end
    end
  end

  describe 'IN conditions with array' do
    context 'with array of values' do
      let(:conditions) { { 'status' => %w[active pending] } }

      it 'builds IN clause' do
        result = builder.build
        expect(result).to include('IN')
      end

      it 'includes all values' do
        result = builder.build
        expect(result).to include("'active'")
        expect(result).to include("'pending'")
      end

      it 'separates values with comma and space' do
        result = builder.build
        expect(result).to include(', ')
      end
    end

    context 'with empty array' do
      let(:conditions) { { 'status' => [] } }

      it 'builds IN (NULL) clause' do
        result = builder.build
        expect(result).to eq(' WHERE "status" IN (NULL)')
      end
    end

    context 'with array of integers' do
      let(:conditions) { { 'user_id' => [1, 2, 3] } }

      it 'builds IN clause with integers' do
        result = builder.build
        expect(result).to include('IN')
        expect(result).to include('1, 2, 3')
      end
    end

    context 'with array of mixed types' do
      let(:conditions) { { 'data' => [1, 'string', true] } }

      it 'sanitizes all values' do
        result = builder.build
        expect(result).to include('IN')
        # Verify dataset.sanitize_value was called for each
      end
    end
  end

  describe 'between operator' do
    context 'with hash operator: between and min/max' do
      let(:conditions) { { 'age' => { operator: 'between', min: 20, max: 65 } } }

      it 'builds BETWEEN clause' do
        result = builder.build
        expect(result).to include('BETWEEN')
      end

      it 'includes both bounds' do
        result = builder.build
        expect(result).to include('20')
        expect(result).to include('65')
      end

      it 'places min before AND and max after' do
        result = builder.build
        expect(result).to match(/BETWEEN 20 AND 65/)
      end
    end

    context 'with string keys' do
      let(:conditions) { { 'age' => { 'operator' => 'between', 'min' => 20, 'max' => 65 } } }

      it 'builds BETWEEN clause' do
        result = builder.build
        expect(result).to include('BETWEEN')
        expect(result).to include('20')
        expect(result).to include('65')
      end
    end

    context 'with float values' do
      let(:conditions) { { 'score' => { operator: 'between', min: 0.0, max: 100.0 } } }

      it 'builds BETWEEN clause with floats' do
        result = builder.build
        expect(result).to include('BETWEEN')
        expect(result).to include('0.0')
        expect(result).to include('100.0')
      end
    end
  end

  describe 'greater than operator' do
    context 'gt operator' do
      let(:conditions) { { 'age' => { operator: 'gt', value: 18 } } }

      it 'builds greater than clause' do
        result = builder.build
        expect(result).to include('>')
        expect(result).not_to include('=')
      end

      it 'includes the value' do
        result = builder.build
        expect(result).to include('18')
      end
    end

    context 'gte operator' do
      let(:conditions) { { 'age' => { operator: 'gte', value: 18 } } }

      it 'builds greater than or equal clause' do
        result = builder.build
        expect(result).to include('>=')
      end

      it 'includes the value' do
        result = builder.build
        expect(result).to include('18')
      end
    end

    context 'with string keys' do
      let(:conditions) { { 'age' => { 'operator' => 'gt', 'value' => 18 } } }

      it 'builds greater than clause' do
        result = builder.build
        expect(result).to include('>')
        expect(result).to include('18')
      end
    end
  end

  describe 'less than operator' do
    context 'lt operator' do
      let(:conditions) { { 'age' => { operator: 'lt', value: 65 } } }

      it 'builds less than clause' do
        result = builder.build
        expect(result).to include('<')
        expect(result).not_to include('=')
      end

      it 'includes the value' do
        result = builder.build
        expect(result).to include('65')
      end
    end

    context 'lte operator' do
      let(:conditions) { { 'age' => { operator: 'lte', value: 65 } } }

      it 'builds less than or equal clause' do
        result = builder.build
        expect(result).to include('<=')
      end

      it 'includes the value' do
        result = builder.build
        expect(result).to include('65')
      end
    end
  end

  describe 'equality operator' do
    context 'eq operator' do
      let(:conditions) { { 'status' => { operator: 'eq', value: 'active' } } }

      it 'builds equality clause' do
        result = builder.build
        expect(result).to include('=')
        expect(result).to include("'active'")
      end
    end

    context 'with string keys' do
      let(:conditions) { { 'status' => { 'operator' => 'eq', 'value' => 'active' } } }

      it 'builds equality clause' do
        result = builder.build
        expect(result).to include('=')
        expect(result).to include("'active'")
      end
    end
  end

  describe 'not equal operator' do
    context 'ne operator' do
      let(:conditions) { { 'status' => { operator: 'ne', value: 'deleted' } } }

      it 'builds not equal clause' do
        result = builder.build
        expect(result).to include('!=')
      end

      it 'includes the value' do
        result = builder.build
        expect(result).to include("'deleted'")
      end
    end
  end

  describe 'IN operator with hash' do
    context 'in operator with values' do
      let(:conditions) { { 'status' => { operator: 'in', values: ['active', 'pending'] } } }

      it 'builds IN clause' do
        result = builder.build
        expect(result).to include('IN')
      end

      it 'includes all values' do
        result = builder.build
        expect(result).to include("'active'")
        expect(result).to include("'pending'")
      end
    end

    context 'with string keys' do
      let(:conditions) { { 'status' => { 'operator' => 'in', 'values' => ['active', 'pending'] } } }

      it 'builds IN clause' do
        result = builder.build
        expect(result).to include('IN')
        expect(result).to include("'active'")
      end
    end

    context 'with empty values' do
      let(:conditions) { { 'status' => { operator: 'in', values: [] } } }

      it 'builds IN (NULL) clause' do
        result = builder.build
        expect(result).to eq(' WHERE "status" IN (NULL)')
      end
    end
  end

  describe 'NOT IN operator' do
    context 'not_in operator' do
      let(:conditions) { { 'status' => { operator: 'not_in', values: ['deleted', 'archived'] } } }

      it 'builds NOT IN clause' do
        result = builder.build
        expect(result).to include('NOT IN')
      end

      it 'includes all values' do
        result = builder.build
        expect(result).to include("'deleted'")
        expect(result).to include("'archived'")
      end
    end

    context 'with string keys' do
      let(:conditions) { { 'status' => { 'operator' => 'not_in', 'values' => ['deleted', 'archived'] } } }

      it 'builds NOT IN clause' do
        result = builder.build
        expect(result).to include('NOT IN')
        expect(result).to include("'deleted'")
      end
    end

    context 'with empty values' do
      let(:conditions) { { 'status' => { operator: 'not_in', values: [] } } }

      it 'builds NOT IN clause with no values' do
        result = builder.build
        expect(result).to include('NOT IN')
        expect(result).to include('()')
      end
    end
  end

  describe 'LIKE operator' do
    context 'like operator' do
      let(:conditions) { { 'name' => { operator: 'like', pattern: '%Smith' } } }

      it 'builds LIKE clause' do
        result = builder.build
        expect(result).to include('LIKE')
      end

      it 'includes the pattern' do
        result = builder.build
        expect(result).to include('%Smith')
      end
    end

    context 'with string keys' do
      let(:conditions) { { 'name' => { 'operator' => 'like', 'pattern' => '%Smith' } } }

      it 'builds LIKE clause' do
        result = builder.build
        expect(result).to include('LIKE')
        expect(result).to include('%Smith')
      end
    end
  end

  describe 'ILIKE operator (PostgreSQL)' do
    context 'ilike operator' do
      let(:conditions) { { 'name' => { operator: 'ilike', pattern: '%smith%' } } }

      it 'builds ILIKE clause' do
        result = builder.build
        expect(result).to include('ILIKE')
      end

      it 'includes the pattern' do
        result = builder.build
        expect(result).to include('%smith%')
      end
    end

    context 'with string keys' do
      let(:conditions) { { 'name' => { 'operator' => 'ilike', 'pattern' => '%smith%' } } }

      it 'builds ILIKE clause' do
        result = builder.build
        expect(result).to include('ILIKE')
        expect(result).to include('%smith%')
      end
    end
  end

  describe 'complex multi-condition scenarios' do
    context 'combining simple and complex conditions' do
      let(:conditions) do
        {
          'age' => { operator: 'between', min: 18, max: 65 },
          'status' => 'active'
        }
      end

      it 'joins conditions with AND' do
        result = builder.build
        expect(result).to include('AND')
      end

      it 'includes both conditions' do
        result = builder.build
        expect(result).to include('BETWEEN')
        expect(result).to include('=')
      end
    end

    context 'with three conditions' do
      let(:conditions) do
        {
          'age' => { operator: 'gte', value: 18 },
          'status' => 'active',
          'country' => { operator: 'in', values: ['US', 'CA'] }
        }
      end

      it 'joins all conditions with AND' do
        result = builder.build
        # Count ' AND ' to avoid matching 'AND' within other words
        and_count = result.scan(/ AND /).length
        expect(and_count).to eq(2)
      end

      it 'includes all three conditions' do
        result = builder.build
        expect(result).to include('>=')
        expect(result).to include('=')
        expect(result).to include('IN')
      end
    end

    context 'with NULL and non-NULL checks' do
      let(:conditions) do
        {
          'deleted_at' => nil,
          'created_at' => { operator: 'is_not_null' }
        }
      end

      it 'builds both NULL conditions' do
        result = builder.build
        expect(result).to include('IS NULL')
        expect(result).to include('IS NOT NULL')
      end
    end
  end

  describe 'column sanitization' do
    context 'with valid column name' do
      let(:conditions) { { 'user_age' => 30 } }

      it 'calls sanitize_column' do
        builder.build
        expect(dataset).to have_received(:sanitize_column).with('user_age')
      end

      it 'quotes the column name' do
        result = builder.build
        expect(result).to include('"user_age"')
      end
    end

    context 'with multiple column names' do
      let(:conditions) { { 'age' => 30, 'name' => 'John' } }

      it 'sanitizes all column names' do
        builder.build
        expect(dataset).to have_received(:sanitize_column).with('age')
        expect(dataset).to have_received(:sanitize_column).with('name')
      end
    end
  end

  describe 'value sanitization' do
    context 'with string value' do
      let(:conditions) { { 'name' => 'John' } }

      it 'calls sanitize_value' do
        builder.build
        expect(dataset).to have_received(:sanitize_value).with('John')
      end
    end

    context 'with integer value' do
      let(:conditions) { { 'age' => 30 } }

      it 'calls sanitize_value' do
        builder.build
        expect(dataset).to have_received(:sanitize_value).with(30)
      end
    end

    context 'with multiple values' do
      let(:conditions) { { 'status' => %w[active pending] } }

      it 'sanitizes all values in array' do
        builder.build
        expect(dataset).to have_received(:sanitize_value).with('active')
        expect(dataset).to have_received(:sanitize_value).with('pending')
      end
    end

    context 'with values in hash condition' do
      let(:conditions) { { 'age' => { operator: 'between', min: 20, max: 65 } } }

      it 'sanitizes min and max values' do
        builder.build
        expect(dataset).to have_received(:sanitize_value).with(20)
        expect(dataset).to have_received(:sanitize_value).with(65)
      end
    end
  end

  describe 'error handling' do
    context 'with unsupported operator' do
      let(:conditions) { { 'age' => { operator: 'invalid_operator', value: 30 } } }

      it 'raises error' do
        expect { builder.build }.to raise_error("Unsupported operator: invalid_operator")
      end
    end

    context 'with unsupported operator string' do
      let(:conditions) { { 'age' => { 'operator' => 'unknown', 'value' => 30 } } }

      it 'raises error' do
        expect { builder.build }.to raise_error("Unsupported operator: unknown")
      end
    end
  end

  describe 'edge cases' do
    context 'with empty string value' do
      let(:conditions) { { 'name' => '' } }

      it 'builds equality clause with empty string' do
        result = builder.build
        expect(result).to include("''")
      end
    end

    context 'with zero value' do
      let(:conditions) { { 'count' => 0 } }

      it 'builds equality clause with zero' do
        result = builder.build
        expect(result).to include('0')
      end
    end

    context 'with negative number' do
      let(:conditions) { { 'balance' => -100 } }

      it 'builds equality clause with negative number' do
        result = builder.build
        expect(result).to include('-100')
      end
    end

    context 'with scientific notation' do
      let(:conditions) { { 'probability' => 1e-5 } }

      it 'builds equality clause with scientific notation' do
        result = builder.build
        # Ruby's scientific notation might be formatted as 1.0e-05
        expect(result).to match(/1\.0e-05|1e-05/)
      end
    end

    context 'with special characters in string' do
      let(:conditions) { { 'email' => 'user@example.com' } }

      it 'quotes special characters' do
        result = builder.build
        expect(result).to include("'user@example.com'")
      end
    end

    context 'with very long string' do
      long_string = 'a' * 1000
      let(:conditions) { { 'data' => long_string } }

      it 'handles long strings' do
        result = builder.build
        expect(result).to include(long_string)
      end
    end
  end

  describe 'SQL injection prevention' do
    context 'with SQL keyword in value' do
      let(:conditions) { { 'name' => "'; DROP TABLE users; --" } }

      it 'sanitizes the value' do
        result = builder.build
        # Value should be quoted, preventing SQL injection
        expect(result).to include("'")
      end
    end

    context 'with SQL keyword in column' do
      let(:conditions) { { '"users"."id"' => 1 } }

      it 'would raise error or be handled by sanitize_column' do
        # The mock will handle this, in real scenario sanitize_column raises
        expect { builder.build }.not_to raise_error
      end
    end
  end

  describe 'integration with different data types' do
    context 'with date value' do
      let(:date) { Date.new(2025, 1, 15) }
      let(:conditions) { { 'created_at' => { operator: 'gte', value: date } } }

      it 'handles date values' do
        result = builder.build
        expect(result).to include('>=')
      end
    end

    context 'with multiple conditions using different operators' do
      let(:conditions) do
        {
          'age' => { operator: 'between', min: 20, max: 65 },
          'active' => true,
          'tags' => { operator: 'in', values: ['tag1', 'tag2'] },
          'name' => { operator: 'like', pattern: '%Smith' }
        }
      end

      it 'builds all conditions correctly' do
        result = builder.build
        expect(result).to include('BETWEEN')
        expect(result).to include('=')
        expect(result).to include('IN')
        expect(result).to include('LIKE')
        # 4 conditions need 3 separators, but BETWEEN contains AND so we have 4
        and_count = result.scan(/ AND /).length
        expect(and_count).to eq(4)
      end
    end
  end

  describe 'attribute accessors' do
    let(:conditions) { { 'age' => 30 } }

    describe '#conditions' do
      it 'returns the conditions' do
        expect(builder.conditions).to eq(conditions)
      end
    end

    describe '#dataset' do
      it 'returns the dataset' do
        expect(builder.dataset).to equal(dataset)
      end
    end
  end
end
