class CreateAuditEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_events do |t|
      t.string :action
      t.references :user, null: false, foreign_key: true
      t.string :target_type
      t.integer :target_id

      t.timestamps
    end
  end
end
