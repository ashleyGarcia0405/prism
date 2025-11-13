namespace :db do
  desc "Inspect database contents"
  task inspect: :environment do
    puts "\n=== DATABASE INSPECTION ==="
    puts "Environment: #{Rails.env}"
    puts "Database: #{ActiveRecord::Base.connection.current_database}"
    puts "\n"

    tables = {
      "Organizations" => Organization,
      "Users" => User,
      "Datasets" => Dataset,
      "Queries" => Query,
      "Runs" => Run,
      "Data Rooms" => DataRoom,
      "Privacy Budgets" => PrivacyBudget
    }

    tables.each do |name, model|
      count = model.count
      puts "#{name}: #{count} records"
    end

    puts "\n=== UPLOADED DATASET TABLES ==="
    uploaded_datasets = Dataset.where.not(table_name: nil)
    if uploaded_datasets.any?
      uploaded_datasets.each do |ds|
        puts "  - #{ds.name} (#{ds.table_name}): #{ds.row_count} rows, #{ds.columns&.size || 0} columns"
      end
    else
      puts "  No uploaded datasets"
    end

    puts "\n=== RECENT ACTIVITY ==="
    if Query.any?
      puts "Latest query: #{Query.last.sql.truncate(60)} (#{Query.last.created_at.strftime('%Y-%m-%d %H:%M')})"
    end
    if Run.any?
      puts "Latest run: #{Run.last.status} (#{Run.last.created_at.strftime('%Y-%m-%d %H:%M')})"
    end

    puts "\n=== DATA ROOMS ==="
    if DataRoom.any?
      DataRoom.all.each do |dr|
        puts "  - #{dr.name}: #{dr.status} (#{dr.attested_count}/#{dr.participant_count} attested)"
      end
    else
      puts "  No data rooms"
    end

    puts "\n"
  end

  desc "Show dataset details"
  task show_datasets: :environment do
    Dataset.all.each do |ds|
      puts "\n=== Dataset: #{ds.name} ==="
      puts "ID: #{ds.id}"
      puts "Organization: #{ds.organization.name}"
      puts "Table: #{ds.table_name || 'Not uploaded'}"
      puts "Rows: #{ds.row_count || 0}"
      puts "Columns: #{ds.columns&.map { |c| "#{c['name']} (#{c['sql_type']})" }&.join(', ') || 'None'}"
      puts "Privacy Budget: #{ds.privacy_budget.remaining_epsilon}/#{ds.privacy_budget.total_epsilon}ε remaining"
      puts "Queries: #{ds.queries.count}"
    end
  end

  desc "Show sample data from a dataset table"
  task :show_data, [ :dataset_id ] => :environment do |t, args|
    dataset = Dataset.find(args[:dataset_id])

    unless dataset.table_name
      puts "Dataset '#{dataset.name}' has no uploaded data yet."
      exit
    end

    puts "\n=== Sample Data from #{dataset.name} ==="
    puts "Table: #{dataset.table_name}"
    puts "Columns: #{dataset.columns.map { |c| c['name'] }.join(', ')}"
    puts "\nFirst 10 rows:\n"

    result = ActiveRecord::Base.connection.execute(
      "SELECT * FROM #{dataset.table_quoted} LIMIT 10"
    )

    result.each do |row|
      puts row.inspect
    end
  end
end
