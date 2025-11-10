class CreateDataRoomInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :data_room_invitations do |t|
      t.references :data_room, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :status, default: "pending", null: false
      t.string :invitation_token, null: false
      t.datetime :expires_at

      t.timestamps
    end

    add_index :data_room_invitations, :invitation_token, unique: true
  end
end
