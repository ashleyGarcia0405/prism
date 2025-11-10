class CreateDataRoomParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :data_room_participants do |t|
      t.references :data_room, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :dataset, null: false, foreign_key: true
      t.string :status, default: "invited", null: false
      t.datetime :attested_at
      t.datetime :computed_at
      t.jsonb :computation_metadata

      t.timestamps
    end

    add_index :data_room_participants, [ :data_room_id, :organization_id ], unique: true, name: "index_participants_on_room_and_org"
  end
end
