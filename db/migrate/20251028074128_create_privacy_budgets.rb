class CreatePrivacyBudgets < ActiveRecord::Migration[8.0]
  def change
    create_table :privacy_budgets do |t|
      t.references :dataset, null: false, foreign_key: true, index: { unique: true }
      t.decimal :total_epsilon, precision: 10, scale: 6, default: 3.0, null: false
      t.decimal :consumed_epsilon, precision: 10, scale: 6, default: 0.0, null: false
      t.decimal :reserved_epsilon, precision: 10, scale: 6, default: 0.0, null: false

      t.timestamps
    end
  end
end
