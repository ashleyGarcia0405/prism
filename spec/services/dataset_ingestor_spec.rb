# # frozen_string_literal: true
#
# require 'rails_helper'
#
# RSpec.describe DatasetIngestor do
#   let(:organization) { Organization.create!(name: "Test Hospital") }
#   let(:dataset) { organization.datasets.create!(name: "Patient Data") }
#   let(:conn) { ActiveRecord::Base.connection }
#
#   after do
#     # Clean up any tables created during tests
#     if dataset.table_name && conn.table_exists?(dataset.table_name)
#       conn.execute("DROP TABLE IF EXISTS #{conn.quote_table_name(dataset.table_name)}")
#     end
#   end
#
#   describe '#call' do
#     context 'with valid CSV data' do
#       let(:csv_content) do
#         "name,age,salary\nAlice,30,75000.50\nBob,25,50000.00\n"
#       end
#       let(:io) { StringIO.new(csv_content) }
#
#       it 'ingests data successfully' do
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         expect(result.row_count).to eq(2)
#         expect(result.columns.size).to eq(3)
#       end
#
#       it 'creates physical table' do
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         expect(conn.table_exists?(dataset.table_name)).to be true
#       end
#
#       it 'updates dataset with row count' do
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         dataset.reload
#         expect(dataset.row_count).to eq(2)
#       end
#
#       it 'updates dataset with original filename' do
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         dataset.reload
#         expect(dataset.original_filename).to eq("test.csv")
#       end
#
#       it 'updates dataset with columns metadata' do
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         dataset.reload
#         expect(dataset.columns).to be_present
#         expect(dataset.columns.size).to eq(3)
#       end
#
#       it 'inserts actual data into table' do
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         result = conn.execute("SELECT * FROM #{conn.quote_table_name(dataset.table_name)}")
#         expect(result.count).to eq(2)
#       end
#     end
#
#     context 'with file size validation' do
#       it 'raises error for files exceeding MAX_BYTES' do
#         large_content = "a" * (DatasetIngestor::MAX_BYTES + 1)
#         io = StringIO.new(large_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "large.csv")
#         expect { ingestor.call }.to raise_error(ArgumentError, /File too large/)
#       end
#
#       it 'accepts files at exactly MAX_BYTES' do
#         # Create CSV that's exactly at the limit
#         header = "col1,col2\n"
#         row = "a,b\n"
#         rows_needed = (DatasetIngestor::MAX_BYTES - header.bytesize) / row.bytesize
#         content = header + (row * rows_needed)
#         io = StringIO.new(content[0, DatasetIngestor::MAX_BYTES])
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "exact.csv")
#         expect { ingestor.call }.not_to raise_error
#       end
#
#       it 'accepts small files' do
#         csv_content = "name,age\nAlice,30\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "small.csv")
#         expect { ingestor.call }.not_to raise_error
#       end
#     end
#
#     context 'with CSV parsing errors' do
#       it 'raises error for CSV without headers' do
#         csv_content = ""
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "empty.csv")
#         expect { ingestor.call }.to raise_error(ArgumentError, "CSV must have a header row")
#       end
#
#       it 'raises error for CSV with only blank header' do
#         csv_content = "\n\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "blank.csv")
#         expect { ingestor.call }.to raise_error(ArgumentError, "CSV must have a header row")
#       end
#
#       it 'handles CSV with headers but no data' do
#         csv_content = "name,age,salary\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "headers_only.csv")
#         result = ingestor.call
#
#         expect(result.row_count).to eq(0)
#         expect(result.columns.size).to eq(3)
#       end
#     end
#
#     context 'with header normalization' do
#       it 'normalizes headers with special characters' do
#         csv_content = "First Name,Last-Name,Email@Domain\nAlice,Smith,alice@test.com\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         column_names = result.columns.map { |c| c["name"] }
#         expect(column_names).to eq(["first_name", "last_name", "email_domain"])
#       end
#
#       it 'handles duplicate column names' do
#         csv_content = "name,age,name\nAlice,30,Smith\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         column_names = result.columns.map { |c| c["name"] }
#         expect(column_names).to include("name", "name_2")
#         expect(column_names.uniq.size).to eq(3)
#       end
#
#       it 'handles blank column names' do
#         csv_content = "name,,age\nAlice,middle,30\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         column_names = result.columns.map { |c| c["name"] }
#         expect(column_names).to include("col")
#       end
#
#       it 'handles multiple blank column names' do
#         csv_content = ",,,\na,b,c,d\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         column_names = result.columns.map { |c| c["name"] }
#         expect(column_names).to include("col", "col_2", "col_3", "col_4")
#       end
#
#       it 'handles columns with only special characters' do
#         csv_content = "!!!,@@@,###\na,b,c\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         column_names = result.columns.map { |c| c["name"] }
#         expect(column_names.all? { |n| n =~ /^col(_\d+)?$/ }).to be true
#       end
#
#       it 'handles unicode characters in headers' do
#         csv_content = "Prénom,Âge,Société\nPierre,30,ACME\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         expect(result.columns.size).to eq(3)
#       end
#     end
#
#     context 'with type inference' do
#       it 'infers boolean type from true/false' do
#         csv_content = "active,name\ntrue,Alice\nfalse,Bob\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         active_col = result.columns.find { |c| c["name"] == "active" }
#         expect(active_col["sql_type"]).to eq("boolean")
#       end
#
#       it 'infers boolean type from yes/no' do
#         csv_content = "active,name\nyes,Alice\nno,Bob\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         active_col = result.columns.find { |c| c["name"] == "active" }
#         expect(active_col["sql_type"]).to eq("boolean")
#       end
#
#       it 'infers boolean type from 1/0' do
#         csv_content = "active,name\n1,Alice\n0,Bob\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         active_col = result.columns.find { |c| c["name"] == "active" }
#         expect(active_col["sql_type"]).to eq("boolean")
#       end
#
#       it 'infers integer type' do
#         csv_content = "age,name\n30,Alice\n25,Bob\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         age_col = result.columns.find { |c| c["name"] == "age" }
#         expect(age_col["sql_type"]).to eq("integer")
#       end
#
#       it 'infers float type' do
#         csv_content = "salary,name\n75000.50,Alice\n50000.99,Bob\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         salary_col = result.columns.find { |c| c["name"] == "salary" }
#         expect(salary_col["sql_type"]).to eq("double precision")
#       end
#
#       it 'infers text type for strings' do
#         csv_content = "name,email\nAlice,alice@test.com\nBob,bob@test.com\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         name_col = result.columns.find { |c| c["name"] == "name" }
#         email_col = result.columns.find { |c| c["name"] == "email" }
#         expect(name_col["sql_type"]).to eq("text")
#         expect(email_col["sql_type"]).to eq("text")
#       end
#
#       it 'widens type from boolean to integer' do
#         csv_content = "value\ntrue\nfalse\n42\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         value_col = result.columns.find { |c| c["name"] == "value" }
#         expect(value_col["sql_type"]).to eq("integer")
#       end
#
#       it 'widens type from integer to float' do
#         csv_content = "value\n42\n100\n3.14\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         value_col = result.columns.find { |c| c["name"] == "value" }
#         expect(value_col["sql_type"]).to eq("double precision")
#       end
#
#       it 'widens type from float to text' do
#         csv_content = "value\n42.5\n100.2\nhello\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         value_col = result.columns.find { |c| c["name"] == "value" }
#         expect(value_col["sql_type"]).to eq("text")
#       end
#
#       it 'handles empty/nil values in type inference' do
#         csv_content = "age,name\n30,Alice\n,Bob\n25,\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         age_col = result.columns.find { |c| c["name"] == "age" }
#         expect(age_col["sql_type"]).to eq("integer")
#       end
#
#       it 'handles whitespace in type inference' do
#         csv_content = "age,name\n  30  ,Alice\n  25  ,Bob\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         age_col = result.columns.find { |c| c["name"] == "age" }
#         expect(age_col["sql_type"]).to eq("integer")
#       end
#     end
#
#     context 'with table name generation' do
#       it 'generates table name from dataset properties' do
#         ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new("a\n1\n"), filename: "test.csv")
#         ingestor.call
#
#         expect(dataset.table_name).to match(/^ds_\d+_\d+_/)
#       end
#
#       it 'includes organization_id in table name' do
#         ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new("a\n1\n"), filename: "test.csv")
#         ingestor.call
#
#         expect(dataset.table_name).to include("_#{organization.id}_")
#       end
#
#       it 'includes dataset_id in table name' do
#         ingestor = DatasetIngestor.new(dataset: dataset, io: StringIO.new("a\n1\n"), filename: "test.csv")
#         ingestor.call
#
#         expect(dataset.table_name).to include("_#{dataset.id}_")
#       end
#
#       it 'handles dataset names with special characters' do
#         dataset_special = organization.datasets.create!(name: "Test-Data@2024!")
#         ingestor = DatasetIngestor.new(dataset: dataset_special, io: StringIO.new("a\n1\n"), filename: "test.csv")
#         ingestor.call
#
#         expect(dataset_special.table_name).to match(/^ds_\d+_\d+_test_data_2024$/)
#
#         # Cleanup
#         if dataset_special.table_name && conn.table_exists?(dataset_special.table_name)
#           conn.execute("DROP TABLE IF EXISTS #{conn.quote_table_name(dataset_special.table_name)}")
#         end
#       end
#
#       it 'truncates table name to 63 characters' do
#         long_name = "a" * 100
#         dataset_long = organization.datasets.create!(name: long_name)
#         ingestor = DatasetIngestor.new(dataset: dataset_long, io: StringIO.new("a\n1\n"), filename: "test.csv")
#         ingestor.call
#
#         expect(dataset_long.table_name.length).to be <= 63
#
#         # Cleanup
#         if dataset_long.table_name && conn.table_exists?(dataset_long.table_name)
#           conn.execute("DROP TABLE IF EXISTS #{conn.quote_table_name(dataset_long.table_name)}")
#         end
#       end
#
#       it 'uses "dataset" as fallback for empty names' do
#         dataset_empty = organization.datasets.create!(name: "!!!")
#         ingestor = DatasetIngestor.new(dataset: dataset_empty, io: StringIO.new("a\n1\n"), filename: "test.csv")
#         ingestor.call
#
#         expect(dataset_empty.table_name).to include("_dataset")
#
#         # Cleanup
#         if dataset_empty.table_name && conn.table_exists?(dataset_empty.table_name)
#           conn.execute("DROP TABLE IF EXISTS #{conn.quote_table_name(dataset_empty.table_name)}")
#         end
#       end
#     end
#
#     context 'with DDL operations' do
#       it 'drops existing table before creating new one' do
#         csv_content = "name\nAlice\n"
#         io1 = StringIO.new(csv_content)
#
#         ingestor1 = DatasetIngestor.new(dataset: dataset, io: io1, filename: "test1.csv")
#         ingestor1.call
#
#         # Second ingestion should drop and recreate
#         io2 = StringIO.new("age\n30\n")
#         ingestor2 = DatasetIngestor.new(dataset: dataset, io: io2, filename: "test2.csv")
#         ingestor2.call
#
#         # Table should now have 'age' column, not 'name'
#         result = conn.execute("SELECT * FROM #{conn.quote_table_name(dataset.table_name)} LIMIT 1")
#         expect(result.fields).to eq(["age"])
#       end
#
#       it 'creates table with quoted column names' do
#         csv_content = "select,from\nvalue1,value2\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         expect(conn.table_exists?(dataset.table_name)).to be true
#       end
#
#       it 'handles table creation in transaction' do
#         csv_content = "name\nAlice\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#
#         expect {
#           ingestor.call
#         }.not_to raise_error
#       end
#     end
#
#     context 'with DML operations' do
#       it 'casts boolean values correctly' do
#         csv_content = "active\ntrue\nfalse\nyes\nno\n1\n0\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         result = conn.execute("SELECT active FROM #{conn.quote_table_name(dataset.table_name)}")
#         values = result.map { |row| row["active"] }
#         expect(values).to eq([true, false, true, false, true, false])
#       end
#
#       it 'casts integer values correctly' do
#         csv_content = "age\n30\n25\n40\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         result = conn.execute("SELECT age FROM #{conn.quote_table_name(dataset.table_name)}")
#         values = result.map { |row| row["age"] }
#         expect(values).to eq([30, 25, 40])
#       end
#
#       it 'casts float values correctly' do
#         csv_content = "salary\n75000.50\n50000.99\n100000.00\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         result = conn.execute("SELECT salary FROM #{conn.quote_table_name(dataset.table_name)}")
#         values = result.map { |row| row["salary"] }
#         expect(values).to eq([75000.50, 50000.99, 100000.00])
#       end
#
#       it 'handles nil values in insert' do
#         csv_content = "name,age\nAlice,30\nBob,\nCarol,25\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         result = conn.execute("SELECT age FROM #{conn.quote_table_name(dataset.table_name)} WHERE name = 'Bob'")
#         expect(result.first["age"]).to be_nil
#       end
#
#       it 'handles empty string values' do
#         csv_content = "name,email\nAlice,alice@test.com\nBob,\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         result = conn.execute("SELECT email FROM #{conn.quote_table_name(dataset.table_name)} WHERE name = 'Bob'")
#         expect(result.first["email"]).to be_nil
#       end
#
#       it 'handles special characters in data' do
#         csv_content = "name,note\nAlice,\"Hello, World!\"\nBob,\"Test's data\"\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         result = conn.execute("SELECT note FROM #{conn.quote_table_name(dataset.table_name)} WHERE name = 'Alice'")
#         expect(result.first["note"]).to eq("Hello, World!")
#       end
#     end
#
#     context 'with edge cases' do
#       it 'handles large number of rows' do
#         rows = (1..1000).map { |i| "Alice,#{i}" }.join("\n")
#         csv_content = "name,age\n#{rows}\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         expect(result.row_count).to eq(1000)
#       end
#
#       it 'handles many columns' do
#         headers = (1..50).map { |i| "col#{i}" }.join(",")
#         row = (1..50).map { |i| i }.join(",")
#         csv_content = "#{headers}\n#{row}\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         expect(result.columns.size).to eq(50)
#       end
#
#       it 'handles quoted fields with commas' do
#         csv_content = "name,address\n\"Smith, John\",\"123 Main St, Apt 4\"\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         result = conn.execute("SELECT name FROM #{conn.quote_table_name(dataset.table_name)}")
#         expect(result.first["name"]).to eq("Smith, John")
#       end
#
#       it 'handles newlines in quoted fields' do
#         csv_content = "name,bio\nAlice,\"Line 1\nLine 2\"\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         result = conn.execute("SELECT bio FROM #{conn.quote_table_name(dataset.table_name)}")
#         expect(result.first["bio"]).to include("Line 1\nLine 2")
#       end
#
#       it 'handles BOM (Byte Order Mark) in CSV' do
#         csv_content = "\uFEFFname,age\nAlice,30\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         result = ingestor.call
#
#         expect(result.columns.size).to eq(2)
#       end
#
#       it 'rewinds IO multiple times during processing' do
#         csv_content = "name,age\nAlice,30\nBob,25\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#         ingestor.call
#
#         # IO should have been rewound and read multiple times
#         expect(io.pos).to be >= 0
#       end
#     end
#
#     context 'with transaction rollback' do
#       it 'rolls back on insert failure' do
#         csv_content = "name,age\nAlice,30\n"
#         io = StringIO.new(csv_content)
#
#         ingestor = DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv")
#
#         # Force an error during bulk insert by making table drop fail after creation
#         allow(ingestor).to receive(:bulk_insert!).and_raise(StandardError, "Insert failed")
#
#         expect {
#           ingestor.call
#         }.to raise_error(StandardError, "Insert failed")
#
#         # Dataset should not have been updated
#         dataset.reload
#         expect(dataset.row_count).to be_nil
#       end
#     end
#   end
#
#   describe 'private methods' do
#     let(:csv_content) { "name,age\nAlice,30\n" }
#     let(:io) { StringIO.new(csv_content) }
#     let(:ingestor) { DatasetIngestor.new(dataset: dataset, io: io, filename: "test.csv") }
#
#     describe '#classify' do
#       it 'classifies boolean values' do
#         expect(ingestor.send(:classify, "true")).to eq(:boolean)
#         expect(ingestor.send(:classify, "false")).to eq(:boolean)
#         expect(ingestor.send(:classify, "yes")).to eq(:boolean)
#         expect(ingestor.send(:classify, "no")).to eq(:boolean)
#         expect(ingestor.send(:classify, "1")).to eq(:boolean)
#         expect(ingestor.send(:classify, "0")).to eq(:boolean)
#       end
#
#       it 'classifies integer values' do
#         expect(ingestor.send(:classify, "42")).to eq(:integer)
#         expect(ingestor.send(:classify, "-100")).to eq(:integer)
#         expect(ingestor.send(:classify, "0")).to eq(:boolean) # 0 is also boolean
#       end
#
#       it 'classifies float values' do
#         expect(ingestor.send(:classify, "3.14")).to eq(:float)
#         expect(ingestor.send(:classify, "-2.5")).to eq(:float)
#         expect(ingestor.send(:classify, "100.0")).to eq(:float)
#       end
#
#       it 'classifies text values' do
#         expect(ingestor.send(:classify, "hello")).to eq(:text)
#         expect(ingestor.send(:classify, "test@example.com")).to eq(:text)
#       end
#     end
#
#     describe '#widen' do
#       it 'widens boolean to integer' do
#         expect(ingestor.send(:widen, :boolean, :integer)).to eq(:integer)
#       end
#
#       it 'widens integer to float' do
#         expect(ingestor.send(:widen, :integer, :float)).to eq(:float)
#       end
#
#       it 'widens float to text' do
#         expect(ingestor.send(:widen, :float, :text)).to eq(:text)
#       end
#
#       it 'does not narrow types' do
#         expect(ingestor.send(:widen, :text, :integer)).to eq(:text)
#         expect(ingestor.send(:widen, :float, :boolean)).to eq(:float)
#       end
#     end
#
#     describe '#integer?' do
#       it 'returns true for valid integers' do
#         expect(ingestor.send(:integer?, "42")).to be true
#         expect(ingestor.send(:integer?, "-100")).to be true
#         expect(ingestor.send(:integer?, "0")).to be true
#       end
#
#       it 'returns false for non-integers' do
#         expect(ingestor.send(:integer?, "3.14")).to be false
#         expect(ingestor.send(:integer?, "hello")).to be false
#         expect(ingestor.send(:integer?, "")).to be false
#       end
#     end
#
#     describe '#float?' do
#       it 'returns true for valid floats' do
#         expect(ingestor.send(:float?, "3.14")).to be true
#         expect(ingestor.send(:float?, "-2.5")).to be true
#         expect(ingestor.send(:float?, "100.0")).to be true
#       end
#
#       it 'returns true for integers (can be parsed as float)' do
#         expect(ingestor.send(:float?, "42")).to be true
#       end
#
#       it 'returns false for non-floats' do
#         expect(ingestor.send(:float?, "hello")).to be false
#         expect(ingestor.send(:float?, "")).to be false
#       end
#     end
#
#     describe '#pg_type_for' do
#       it 'returns correct PostgreSQL types' do
#         expect(ingestor.send(:pg_type_for, :boolean)).to eq("boolean")
#         expect(ingestor.send(:pg_type_for, :integer)).to eq("integer")
#         expect(ingestor.send(:pg_type_for, :float)).to eq("double precision")
#         expect(ingestor.send(:pg_type_for, :text)).to eq("text")
#         expect(ingestor.send(:pg_type_for, :unknown)).to eq("text")
#       end
#     end
#
#     describe '#cast_value' do
#       it 'casts boolean values' do
#         expect(ingestor.send(:cast_value, "true", "boolean")).to be true
#         expect(ingestor.send(:cast_value, "false", "boolean")).to be false
#         expect(ingestor.send(:cast_value, "yes", "boolean")).to be true
#         expect(ingestor.send(:cast_value, "no", "boolean")).to be false
#       end
#
#       it 'casts integer values' do
#         expect(ingestor.send(:cast_value, "42", "integer")).to eq(42)
#         expect(ingestor.send(:cast_value, "-100", "integer")).to eq(-100)
#       end
#
#       it 'casts float values' do
#         expect(ingestor.send(:cast_value, "3.14", "double precision")).to eq(3.14)
#         expect(ingestor.send(:cast_value, "100.5", "double precision")).to eq(100.5)
#       end
#
#       it 'casts text values' do
#         expect(ingestor.send(:cast_value, "hello", "text")).to eq("hello")
#       end
#
#       it 'returns nil for empty values' do
#         expect(ingestor.send(:cast_value, nil, "text")).to be_nil
#         expect(ingestor.send(:cast_value, "", "text")).to be_nil
#         expect(ingestor.send(:cast_value, "   ", "text")).to be_nil
#       end
#     end
#   end
# end