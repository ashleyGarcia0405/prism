class AddDeltaToQueries < ActiveRecord::Migration[8.0]
  def change
    add_column :queries, :delta, :decimal, precision: 10, scale: 10, default: 0.00001
  end
end
