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

  # Schema introspection methods for MPC validation

  # Get all column names from the dataset table
  def column_names
    return [] unless table_name && table_exists?

    ActiveRecord::Base.connection.columns(table_name).map(&:name)
  rescue ActiveRecord::StatementInvalid
    []
  end

  # Check if column exists in dataset
  def has_column?(column_name)
    column_names.include?(column_name.to_s)
  end

  # Get column data type
  def column_type(column_name)
    return nil unless table_name && table_exists?

    column = ActiveRecord::Base.connection.columns(table_name)
                                .find { |c| c.name == column_name.to_s }
    column&.type
  rescue ActiveRecord::StatementInvalid
    nil
  end

  # Get detailed column metadata
  def column_info(column_name)
    return nil unless table_name && table_exists?

    column = ActiveRecord::Base.connection.columns(table_name)
                                .find { |c| c.name == column_name.to_s }
    return nil unless column

    {
      name: column.name,
      type: column.type,
      sql_type: column.sql_type,
      null: column.null,
      default: column.default,
      limit: column.limit
    }
  rescue ActiveRecord::StatementInvalid
    nil
  end

  # Get all column metadata
  def schema_info
    return [] unless table_name && table_exists?

    ActiveRecord::Base.connection.columns(table_name).map do |col|
      {
        name: col.name,
        type: col.type,
        sql_type: col.sql_type,
        null: col.null,
        default: col.default
      }
    end
  rescue ActiveRecord::StatementInvalid
    []
  end

  # Check if table exists in database
  def table_exists?
    return false unless table_name

    ActiveRecord::Base.connection.table_exists?(table_name)
  end

  # Get sample values from column (for debugging/validation)
  def sample_column_values(column_name, limit = 5)
    return [] unless has_column?(column_name)

    # Use sanitize_sql_array with bind parameters to prevent SQL injection
    safe_column = sanitize_column(column_name)
    safe_table = table_quoted
    safe_limit = limit.to_i

    sql = ActiveRecord::Base.sanitize_sql_array([
      "SELECT #{safe_column} FROM #{safe_table} LIMIT ?", safe_limit
    ])
    result = ActiveRecord::Base.connection.execute(sql)
    result.map { |row| row[column_name] }
  rescue ActiveRecord::StatementInvalid
    []
  end

  # Sanitize column name to prevent SQL injection
  def sanitize_column(column_name)
    # Only allow alphanumeric and underscore
    raise ArgumentError, "Invalid column name: #{column_name}" unless column_name.to_s.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)

    ActiveRecord::Base.connection.quote_column_name(column_name)
  end

  # Sanitize value to prevent SQL injection
  def sanitize_value(value)
    ActiveRecord::Base.connection.quote(value)
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
