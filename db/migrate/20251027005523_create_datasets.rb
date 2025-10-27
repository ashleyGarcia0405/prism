class CreateDatasets < ActiveRecord::Migration[8.0]
  def change
    create_table :datasets do |t|
      t.string :name
      t.references :organization, null: false, foreign_key: true

      t.timestamps
    end
  end
end
