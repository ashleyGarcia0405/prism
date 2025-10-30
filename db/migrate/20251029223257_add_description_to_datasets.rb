class AddDescriptionToDatasets < ActiveRecord::Migration[8.0]
  def change
    add_column :datasets, :description, :text
  end
end
