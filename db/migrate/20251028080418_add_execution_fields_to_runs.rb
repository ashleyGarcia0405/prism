class AddExecutionFieldsToRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :runs, :backend_used, :string
    add_column :runs, :epsilon_consumed, :decimal, precision: 10, scale: 6
    add_column :runs, :proof_artifacts, :jsonb, default: {}
    add_column :runs, :execution_time_ms, :integer
    add_column :runs, :error_message, :text
    add_reference :runs, :user, foreign_key: true

    add_index :runs, :status
    add_index :runs, :backend_used
  end
end
