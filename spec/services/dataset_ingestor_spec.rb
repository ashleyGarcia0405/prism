require 'rails_helper'
require 'csv'
require 'stringio'

RSpec.describe DatasetIngestor do
  let(:organization) { Organization.create!(name: "Test Org") }
  let(:dataset) { organization.datasets.create!(name: "Test Dataset") }

  def csv_io(content)
    StringIO.new(content)
  end

  # Helper to create a CSV string
  def make_csv(*rows)
    CSV.generate do |csv|
      rows.each { |row| csv << row }
    end
  end

  describe '#call' do
    describe 'file size validation' do
      it 'raises ArgumentError if file exceeds MAX_BYTES' do
        # Create a large string and StringIO
        large_content = 'x' * (11 * 1024 * 1024) # 11 MB
        large_io = StringIO.new(large_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: large_io, filename: 'large.csv')
        expect { ingestor.call }.to raise_error(ArgumentError, /File too large/)
      end

      it 'accepts file at exactly MAX_BYTES' do
        csv_content = make_csv(['col1', 'col2'], [1, 2])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        # Should not raise
        result = ingestor.call
        expect(result).to be_a(DatasetIngestor::IngestResult)
      end
    end

    describe 'header validation' do
      it 'raises ArgumentError if CSV has no headers' do
        # A CSV-like string with just newlines
        empty_csv = "\n\n"
        io = csv_io(empty_csv)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'empty.csv')
        expect { ingestor.call }.to raise_error(ArgumentError, /CSV must have a header row/)
      end

      it 'properly loads valid CSV headers' do
        csv_content = make_csv(['col1', 'col2'], [1, 2])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'valid.csv')
        result = ingestor.call
        
        expect(result.columns.count).to eq(2)
      end
    end

    describe 'table name generation' do
      it 'uses default_table_name if dataset.table_name is nil' do
        dataset.update!(table_name: nil)
        csv_content = make_csv(['name', 'age'], ['Alice', 30])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(dataset.reload.table_name).to include("ds_#{dataset.organization_id}_#{dataset.id}")
      end

      it 'uses existing table_name if already set' do
        custom_table = 'my_custom_table'
        dataset.update!(table_name: custom_table)
        csv_content = make_csv(['col1'], [1])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(dataset.reload.table_name).to eq(custom_table)
      end

      it 'truncates table name to 63 characters (Postgres limit)' do
        dataset.update!(table_name: nil)
        dataset.update!(name: 'a' * 100) # Very long name

        csv_content = make_csv(['col1'], [1])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.call

        table_name = dataset.reload.table_name
        expect(table_name.length).to be <= 63
      end
    end

    describe 'header normalization' do
      it 'normalizes headers to lowercase with underscores' do
        csv_content = make_csv(['First Name', 'Age Group', 'Salary/Hour'])
        csv_content += make_csv(['John', 25, 15])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(result.columns.map { |c| c['name'] }).to include('first_name', 'age_group', 'salary_hour')
      end

      it 'handles duplicate header names by appending numeric suffix' do
        csv_content = make_csv(['name', 'name', 'name'])
        csv_content += make_csv(['a', 'b', 'c'])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        names = result.columns.map { |c| c['name'] }
        expect(names).to include('name', 'name_2', 'name_3')
      end

      it 'removes leading and trailing special characters from headers' do
        csv_content = make_csv(['__name__', '___age___'])
        csv_content += make_csv(['John', 25])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(result.columns.map { |c| c['name'] }).to eq(['name', 'age'])
      end

      it 'converts blank headers to "col"' do
        csv_content = make_csv(['', 'name', ''])
        csv_content += make_csv(['val1', 'John', 'val2'])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        names = result.columns.map { |c| c['name'] }
        expect(names).to eq(['col', 'name', 'col_2'])
      end

      it 'handles headers with non-ASCII characters' do
        csv_content = make_csv(['café', 'naïve', 'über'])
        csv_content += make_csv(['a', 'b', 'c'])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        # Non-ASCII characters should be replaced
        names = result.columns.map { |c| c['name'] }
        expect(names).to all(match(/^[a-z0-9_]+$/))
      end
    end

    describe 'type inference' do
      it 'infers boolean type from true/false strings' do
        csv_content = make_csv(
          ['active', 'value'],
          ['true', 1],
          ['false', 2]
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        active_col = result.columns.find { |c| c['name'] == 'active' }
        expect(active_col['sql_type']).to eq('boolean')
      end

      it 'infers boolean type from t/f abbreviations' do
        csv_content = make_csv(
          ['flag'],
          ['t'],
          ['f']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        flag_col = result.columns.find { |c| c['name'] == 'flag' }
        expect(flag_col['sql_type']).to eq('boolean')
      end

      it 'infers boolean type from yes/no' do
        csv_content = make_csv(
          ['consent'],
          ['yes'],
          ['no']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        consent_col = result.columns.find { |c| c['name'] == 'consent' }
        expect(consent_col['sql_type']).to eq('boolean')
      end

      it 'infers boolean type from 1/0' do
        csv_content = make_csv(
          ['binary'],
          ['1'],
          ['0']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        binary_col = result.columns.find { |c| c['name'] == 'binary' }
        expect(binary_col['sql_type']).to eq('boolean')
      end

      it 'infers integer type for whole numbers' do
        csv_content = make_csv(
          ['count', 'value'],
          ['100', 50],
          ['200', 75]
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        count_col = result.columns.find { |c| c['name'] == 'count' }
        expect(count_col['sql_type']).to eq('integer')
      end

      it 'infers float type when integers are mixed with floats' do
        csv_content = make_csv(
          ['value'],
          ['100'],
          ['100.5']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        value_col = result.columns.find { |c| c['name'] == 'value' }
        expect(value_col['sql_type']).to eq('double precision')
      end

      it 'widens boolean to integer when integer values appear' do
        csv_content = make_csv(
          ['value'],
          ['true'],
          ['100']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        value_col = result.columns.find { |c| c['name'] == 'value' }
        expect(value_col['sql_type']).to eq('integer')
      end

      it 'widens integer to float when float values appear' do
        csv_content = make_csv(
          ['value'],
          ['100'],
          ['100.5']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        value_col = result.columns.find { |c| c['name'] == 'value' }
        expect(value_col['sql_type']).to eq('double precision')
      end

      it 'widens any type to text when non-numeric values appear' do
        csv_content = make_csv(
          ['value'],
          ['100'],
          ['not a number']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        value_col = result.columns.find { |c| c['name'] == 'value' }
        expect(value_col['sql_type']).to eq('text')
      end

      it 'stays boolean when all values are boolean-like' do
        csv_content = make_csv(
          ['flag'],
          ['true'],
          ['false'],
          ['yes'],
          ['no']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        flag_col = result.columns.find { |c| c['name'] == 'flag' }
        expect(flag_col['sql_type']).to eq('boolean')
      end

      it 'ignores nil and empty values during type inference' do
        csv_content = make_csv(
          ['value'],
          ['100'],
          [''],
          [nil],
          ['200']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        value_col = result.columns.find { |c| c['name'] == 'value' }
        expect(value_col['sql_type']).to eq('integer')
      end

      it 'defaults to boolean if all values are nil or empty' do
        csv_content = make_csv(
          ['empty_col'],
          [''],
          [nil]
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        empty_col = result.columns.find { |c| c['name'] == 'empty_col' }
        expect(empty_col['sql_type']).to eq('boolean')
      end

      it 'handles negative integers' do
        csv_content = make_csv(
          ['temperature'],
          ['-10'],
          ['5'],
          ['-25']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        temp_col = result.columns.find { |c| c['name'] == 'temperature' }
        expect(temp_col['sql_type']).to eq('integer')
      end

      it 'handles negative floats' do
        csv_content = make_csv(
          ['balance'],
          ['-10.50'],
          ['5.75'],
          ['-25.99']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        balance_col = result.columns.find { |c| c['name'] == 'balance' }
        expect(balance_col['sql_type']).to eq('double precision')
      end

      it 'handles scientific notation as float' do
        csv_content = make_csv(
          ['value'],
          ['1e-10'],
          ['5.5e3']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        value_col = result.columns.find { |c| c['name'] == 'value' }
        expect(value_col['sql_type']).to eq('double precision')
      end

      it 'handles whitespace-only values as nil' do
        csv_content = make_csv(
          ['value'],
          ['100'],
          ['   '],
          ['200']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        value_col = result.columns.find { |c| c['name'] == 'value' }
        expect(value_col['sql_type']).to eq('integer')
      end
    end

    describe 'data insertion' do
      it 'inserts all rows from CSV into the database table' do
        csv_content = make_csv(
          ['name', 'age'],
          ['Alice', '30'],
          ['Bob', '25'],
          ['Charlie', '35']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(result.row_count).to eq(3)
        expect(dataset.reload.row_count).to eq(3)
      end

      it 'casts boolean values correctly (true variants)' do
        csv_content = make_csv(
          ['flag'],
          ['true'],
          ['t'],
          ['yes'],
          ['1']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.call

        table = dataset.table_name
        values = ActiveRecord::Base.connection.execute("SELECT flag FROM #{table}")
        expect(values.count).to eq(4)
        values.each { |row| expect(row['flag']).to be true }
      end

      it 'casts boolean values correctly (false variants)' do
        csv_content = make_csv(
          ['flag'],
          ['false'],
          ['f'],
          ['no'],
          ['0']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.call

        table = dataset.table_name
        values = ActiveRecord::Base.connection.execute("SELECT flag FROM #{table}")
        expect(values.count).to eq(4)
        values.each { |row| expect(row['flag']).to be false }
      end

      it 'casts integer values correctly' do
        csv_content = make_csv(
          ['count'],
          ['100'],
          ['200'],
          ['300']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.call

        table = dataset.table_name
        values = ActiveRecord::Base.connection.execute("SELECT count FROM #{table}")
        expect(values.map { |row| row['count'] }).to eq([100, 200, 300])
      end

      it 'casts float values correctly' do
        csv_content = make_csv(
          ['price'],
          ['10.50'],
          ['20.75'],
          ['30.99']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.call

        table = dataset.table_name
        values = ActiveRecord::Base.connection.execute("SELECT price FROM #{table}")
        prices = values.map { |row| row['price'] }
        expect(prices).to all(be_a(Float))
      end

      it 'casts text values correctly' do
        csv_content = make_csv(
          ['name'],
          ['Alice'],
          ['Bob'],
          ['Charlie']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.call

        table = dataset.table_name
        values = ActiveRecord::Base.connection.execute("SELECT name FROM #{table}")
        expect(values.map { |row| row['name'] }).to eq(['Alice', 'Bob', 'Charlie'])
      end

      it 'converts nil/empty values to nil in database' do
        csv_content = make_csv(
          ['value'],
          ['100'],
          [''],
          ['200']
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.call

        table = dataset.table_name
        values = ActiveRecord::Base.connection.execute("SELECT value FROM #{table}")
        expect(values[1]['value']).to be_nil
      end

      it 'handles large number of rows' do
        rows = [['id', 'value']]
        100.times { |i| rows << [i, i * 10] }
        csv_content = rows.map { |row| CSV.generate_line(row) }.join

        io = csv_io(csv_content)
        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(result.row_count).to eq(100)
      end

      it 'preserves original filename in dataset' do
        csv_content = make_csv(['col'], [1])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'my_data.csv')
        ingestor.call

        expect(dataset.reload.original_filename).to eq('my_data.csv')
      end
    end

    describe 'transaction handling' do
      it 'rolls back all changes on error during table creation' do
        csv_content = make_csv(['col1'], [1])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')

        # Successfully run the ingestor
        result = ingestor.call
        
        # Verify it worked
        expect(result.row_count).to eq(1)
        expect(dataset.reload.row_count).to eq(1)
      end

      it 'successfully creates table within transaction' do
        csv_content = make_csv(['name', 'age'], ['Alice', '30'])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        table = dataset.table_name
        expect(ActiveRecord::Base.connection.table_exists?(table)).to be true
      end

      it 'drops existing table before creating new one' do
        csv_content = make_csv(['col1'], [1])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result1 = ingestor.call

        # Ingest again with same dataset (should drop and recreate)
        io.rewind
        ingestor2 = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result2 = ingestor2.call

        expect(result2.row_count).to eq(1)
      end
    end

    describe 'IO operations' do
      it 'rewinds IO stream after reading headers' do
        csv_content = make_csv(['col1', 'col2'], [1, 2], [3, 4])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        # Should have read all rows
        expect(result.row_count).to eq(2)
      end

      it 'handles StringIO objects' do
        csv_content = make_csv(['col1'], [1], [2])
        io = StringIO.new(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(result.row_count).to eq(2)
      end

      it 'handles File objects' do
        require 'tempfile'
        csv_content = make_csv(['col1'], [1], [2])
        
        file = Tempfile.new('test.csv')
        file.write(csv_content)
        file.rewind

        begin
          ingestor = DatasetIngestor.new(dataset: dataset, io: file, filename: 'test.csv')
          result = ingestor.call

          expect(result.row_count).to eq(2)
        ensure
          file.close
          file.unlink
        end
      end

      it 'handles UTF-8 encoding with BOM' do
        csv_content = "\xEF\xBB\xBF" + make_csv(['col1'], ['value'])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(result.row_count).to eq(1)
      end

      it 'handles malformed UTF-8 characters' do
        csv_content = make_csv(['col1'], ['valid'])
        # Simulate invalid UTF-8 by using replacement character
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(result.row_count).to eq(1)
      end
    end

    describe 'edge cases' do
      it 'handles column with all nil values' do
        csv_content = make_csv(
          ['name', 'empty'],
          ['Alice', ''],
          ['Bob', nil]
        )
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        empty_col = result.columns.find { |c| c['name'] == 'empty' }
        # Should default to boolean (all nil/empty)
        expect(empty_col['sql_type']).to eq('boolean')
      end

      it 'handles single row (no data, just headers)' do
        csv_content = make_csv(['col1', 'col2'])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(result.row_count).to eq(0)
        expect(result.columns.count).to eq(2)
      end

      it 'handles single column CSV' do
        csv_content = make_csv(['id'], [1], [2], [3])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(result.columns.count).to eq(1)
        expect(result.row_count).to eq(3)
      end

      it 'handles very wide CSV (many columns)' do
        headers = (1..50).map { |i| "col#{i}" }
        rows = [headers]
        rows << (1..50).map(&:to_s)
        csv_content = rows.map { |row| CSV.generate_line(row) }.join

        io = csv_io(csv_content)
        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(result.columns.count).to eq(50)
        expect(result.row_count).to eq(1)
      end

      it 'handles CSV with quoted fields containing commas' do
        csv_content = %{"name","address"\n"Alice","123 Main St, Apt 5"\n"Bob","456 Oak Ave, Suite 100"}
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(result.row_count).to eq(2)
        table = dataset.table_name
        values = ActiveRecord::Base.connection.execute("SELECT address FROM #{table}")
        expect(values.any? { |r| r['address'].include?(',') }).to be true
      end

      it 'handles CSV with quoted fields containing newlines' do
        csv_content = %{"name","bio"\n"Alice","Line 1\nLine 2"\n"Bob","Single line"}
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(result.row_count).to eq(2)
      end

      it 'handles headers with spaces' do
        csv_content = make_csv(['First Name', 'Last Name'])
        csv_content += make_csv(['John', 'Doe'])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        names = result.columns.map { |c| c['name'] }
        expect(names).to eq(['first_name', 'last_name'])
      end

      it 'handles mixed case in CSV values' do
        csv_content = make_csv(['flag'], ['TRUE'], ['False'], ['TrUe'])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        flag_col = result.columns.find { |c| c['name'] == 'flag' }
        expect(flag_col['sql_type']).to eq('boolean')
      end

      it 'handles float with leading/trailing zeros' do
        csv_content = make_csv(['value'], ['0.0'], ['00.50'], ['100.00'])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        value_col = result.columns.find { |c| c['name'] == 'value' }
        expect(value_col['sql_type']).to eq('double precision')
      end
    end

    describe 'return value' do
      it 'returns IngestResult struct with correct attributes' do
        csv_content = make_csv(['col1', 'col2'], [1, 'a'], [2, 'b'])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        result = ingestor.call

        expect(result).to be_a(DatasetIngestor::IngestResult)
        expect(result.row_count).to eq(2)
        expect(result.columns).to be_an(Array)
        expect(result.columns.first.keys).to include('name', 'sql_type')
      end

      it 'updates dataset with result metadata' do
        csv_content = make_csv(['name'], ['Alice'], ['Bob'])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.call

        dataset.reload
        expect(dataset.original_filename).to eq('test.csv')
        expect(dataset.row_count).to eq(2)
        expect(dataset.columns).to be_an(Array)
      end
    end
  end

  # Private method tests
  describe 'private methods' do
    describe '#default_table_name' do
      it 'generates table name from dataset name' do
        dataset.update!(name: 'Customer Data', table_name: nil)
        csv_content = make_csv(['col'], [1])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.call

        expect(dataset.reload.table_name).to include('customer_data')
      end

      it 'replaces non-alphanumeric characters with underscores' do
        dataset.update!(name: 'Data@#$%Set', table_name: nil)
        csv_content = make_csv(['col'], [1])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.call

        table_name = dataset.reload.table_name
        expect(table_name).to match(/^ds_\d+_\d+_data_set/)
      end

      it 'uses "dataset" as default slug if name is very generic' do
        dataset.update!(name: 'Data', table_name: nil)
        csv_content = make_csv(['col'], [1])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.call

        table_name = dataset.reload.table_name
        # Should generate a valid table name
        expect(table_name).to match(/^ds_\d+_\d+_/)
      end

      it 'includes organization_id in table name' do
        dataset.update!(table_name: nil)
        csv_content = make_csv(['col'], [1])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.call

        table_name = dataset.reload.table_name
        expect(table_name).to include(dataset.organization_id.to_s)
      end

      it 'includes dataset_id in table name' do
        dataset.update!(table_name: nil)
        csv_content = make_csv(['col'], [1])
        io = csv_io(csv_content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.call

        table_name = dataset.reload.table_name
        expect(table_name).to include(dataset.id.to_s)
      end
    end

    describe '#safe_size' do
      it 'uses size method if available' do
        io = double('io')
        allow(io).to receive(:respond_to?).and_return(false)
        allow(io).to receive(:respond_to?).with(:size).and_return(true)
        allow(io).to receive(:size).and_return(1000)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        size = ingestor.send(:safe_size, io)

        expect(size).to eq(1000)
      end

      it 'reads full content if size method not available' do
        content = 'test data'
        io = StringIO.new(content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        size = ingestor.send(:safe_size, io)

        expect(size).to eq(content.bytesize)
      end

      it 'rewinds IO after reading size' do
        content = 'test data'
        io = StringIO.new(content)

        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.send(:safe_size, io)

        expect(io.pos).to eq(0)
      end

      it 'restores original position after reading' do
        content = 'test data'
        io = StringIO.new(content)
        io.read(5)  # Move to position 5

        original_pos = io.pos
        ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: 'test.csv')
        ingestor.send(:safe_size, io)

        expect(io.pos).to eq(original_pos)
      end
    end

    describe '#classify' do
      it 'classifies true/false as boolean' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:classify, 'true')).to eq(:boolean)
        expect(ingestor.send(:classify, 'false')).to eq(:boolean)
      end

      it 'classifies t/f as boolean' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:classify, 't')).to eq(:boolean)
        expect(ingestor.send(:classify, 'f')).to eq(:boolean)
      end

      it 'classifies yes/no as boolean' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:classify, 'yes')).to eq(:boolean)
        expect(ingestor.send(:classify, 'no')).to eq(:boolean)
      end

      it 'classifies 1/0 as boolean' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:classify, '1')).to eq(:boolean)
        expect(ingestor.send(:classify, '0')).to eq(:boolean)
      end

      it 'classifies integers as integer' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:classify, '100')).to eq(:integer)
        expect(ingestor.send(:classify, '-50')).to eq(:integer)
        expect(ingestor.send(:classify, '0')).to eq(:boolean) # 0 is boolean
      end

      it 'classifies floats as float' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:classify, '10.5')).to eq(:float)
        expect(ingestor.send(:classify, '-3.14')).to eq(:float)
        expect(ingestor.send(:classify, '1e-5')).to eq(:float)
      end

      it 'classifies other values as text' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:classify, 'hello')).to eq(:text)
        expect(ingestor.send(:classify, 'alice@example.com')).to eq(:text)
      end
    end

    describe '#integer?' do
      it 'returns true for valid integers' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:integer?, '100')).to be true
        expect(ingestor.send(:integer?, '-50')).to be true
      end

      it 'returns false for non-integers' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:integer?, '10.5')).to be false
        expect(ingestor.send(:integer?, 'hello')).to be false
      end
    end

    describe '#float?' do
      it 'returns true for valid floats' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:float?, '10.5')).to be true
        expect(ingestor.send(:float?, '1e-5')).to be true
        expect(ingestor.send(:float?, '100')).to be true # integers are valid floats
      end

      it 'returns false for non-floats' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:float?, 'hello')).to be false
      end
    end

    describe '#widen' do
      it 'returns higher type in hierarchy' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:widen, :boolean, :integer)).to eq(:integer)
        expect(ingestor.send(:widen, :integer, :float)).to eq(:float)
        expect(ingestor.send(:widen, :float, :text)).to eq(:text)
      end

      it 'returns current if observed is lower' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:widen, :text, :float)).to eq(:text)
        expect(ingestor.send(:widen, :integer, :boolean)).to eq(:integer)
      end
    end

    describe '#pg_type_for' do
      it 'maps type symbols to PostgreSQL types' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:pg_type_for, :boolean)).to eq('boolean')
        expect(ingestor.send(:pg_type_for, :integer)).to eq('integer')
        expect(ingestor.send(:pg_type_for, :float)).to eq('double precision')
        expect(ingestor.send(:pg_type_for, :text)).to eq('text')
      end
    end

    describe '#cast_value' do
      it 'returns nil for nil or empty values' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:cast_value, nil, 'text')).to be_nil
        expect(ingestor.send(:cast_value, '', 'text')).to be_nil
        expect(ingestor.send(:cast_value, '   ', 'text')).to be_nil
      end

      it 'casts to boolean' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:cast_value, 'true', 'boolean')).to be true
        expect(ingestor.send(:cast_value, 'false', 'boolean')).to be false
      end

      it 'casts to integer' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:cast_value, '100', 'integer')).to eq(100)
        expect(ingestor.send(:cast_value, '50.7', 'integer')).to eq(50)
      end

      it 'casts to float' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:cast_value, '10.5', 'double precision')).to eq(10.5)
        expect(ingestor.send(:cast_value, '100', 'double precision')).to eq(100.0)
      end

      it 'casts to text' do
        ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new(''), filename: 'test.csv')

        expect(ingestor.send(:cast_value, 'hello', 'text')).to eq('hello')
      end
    end
  end
end
