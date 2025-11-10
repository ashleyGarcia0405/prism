class AddBackendToQueries < ActiveRecord::Migration[8.0]
  def change
    add_column :queries, :backend, :string, default: 'dp_sandbox', null: false
    add_index :queries, :backend
  end
end
