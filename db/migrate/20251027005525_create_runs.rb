class CreateRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :runs do |t|
      t.references :query, null: false, foreign_key: true
      t.string :status
      t.text :result

      t.timestamps
    end
  end
end
