class CreateDataRooms < ActiveRecord::Migration[8.0]
  def change
    create_table :data_rooms do |t|
      t.string :name, null: false
      t.text :description
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.string :status, default: "pending", null: false
      t.text :query_text, null: false
      t.string :query_type
      t.jsonb :query_params
      t.jsonb :result
      t.datetime :executed_at

      t.timestamps
    end
  end
end
