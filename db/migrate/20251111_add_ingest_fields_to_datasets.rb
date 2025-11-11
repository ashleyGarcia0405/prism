# frozen_string_literal: true
class AddIngestFieldsToDatasets < ActiveRecord::Migration[8.0]
  def change
    add_column :datasets, :table_name, :string
    add_column :datasets, :row_count, :integer, default: 0, null: false
    add_column :datasets, :columns, :jsonb, default: [], null: false
    add_column :datasets, :original_filename, :string
    add_index  :datasets, :table_name, unique: true
  end
end
