class ChangeResultToJsonbInRuns < ActiveRecord::Migration[8.0]
  def up
    # Clear existing text data (it's in invalid format anyway)
    execute "UPDATE runs SET result = NULL WHERE result IS NOT NULL"

    # Change column type to jsonb
    change_column :runs, :result, :jsonb, using: 'NULL', default: {}
  end

  def down
    # Revert back to text if needed
    change_column :runs, :result, :text
  end
end
