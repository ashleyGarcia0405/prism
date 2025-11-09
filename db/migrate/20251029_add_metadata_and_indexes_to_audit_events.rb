# db/migrate/20251029_add_metadata_and_indexes_to_audit_events.rb
class AddMetadataAndIndexesToAuditEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :audit_events, :metadata, :jsonb, null: false, default: {}
    add_index  :audit_events, :action
    add_index  :audit_events, :created_at
    add_index  :audit_events, [ :target_type, :target_id ]
    add_index  :audit_events, :metadata, using: :gin
  end
end
