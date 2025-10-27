class CreateQueries < ActiveRecord::Migration[8.0]
  def change
    create_table :queries do |t|
      t.text :sql
      t.references :dataset, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
