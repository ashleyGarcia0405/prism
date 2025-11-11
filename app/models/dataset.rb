class Dataset < ApplicationRecord
  belongs_to :organization
  has_one :privacy_budget, dependent: :destroy
  has_many :queries, dependent: :destroy

  validates :name, presence: true
  validates :table_name, uniqueness: true, allow_nil: true

  after_create :create_default_privacy_budget
  before_create :ensure_table_name

  # columns: [{ "name" => "age", "sql_type" => "integer" }, ...]
  def table_quoted
    ActiveRecord::Base.connection.quote_table_name(table_name)
  end

  private

  def create_default_privacy_budget
    create_privacy_budget!(
      total_epsilon: 3.0,
      consumed_epsilon: 0.0,
      reserved_epsilon: 0.0
    )
  end

  def ensure_table_name
    # short + unique per-org table name (Postgres-safe)
    base = "org#{organization_id}_ds"
    self.table_name ||= "#{base}_#{SecureRandom.hex(6)}"
  end
end
