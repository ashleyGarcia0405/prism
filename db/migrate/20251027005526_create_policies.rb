class CreatePolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :policies do |t|
      t.string :name
      t.references :organization, null: false, foreign_key: true
      t.text :rules

      t.timestamps
    end
  end
end
