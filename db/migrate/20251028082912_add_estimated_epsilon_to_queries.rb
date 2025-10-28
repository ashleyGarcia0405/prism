class AddEstimatedEpsilonToQueries < ActiveRecord::Migration[8.0]
  def change
    add_column :queries, :estimated_epsilon, :decimal, precision: 10, scale: 6
  end
end
