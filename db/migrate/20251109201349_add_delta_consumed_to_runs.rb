class AddDeltaConsumedToRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :runs, :delta_consumed, :decimal, precision: 10, scale: 10
  end
end
