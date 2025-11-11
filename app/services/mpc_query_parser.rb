# frozen_string_literal: true

# MPCQueryParser parses and validates MPC query parameters
# Converts query parameters into executable SQL for each dataset
class MPCQueryParser
  attr_reader :query_params

  def initialize(query_params)
    @query_params = query_params || {}
  end

  # Extract column name from query
  def column_name
    @query_params['column'] || @query_params[:column]
  end

  # Extract query type (sum, count, avg)
  def query_type
    (@query_params['query_type'] || @query_params[:query_type])&.to_s&.downcase
  end

  # Extract WHERE conditions
  def where_conditions
    @query_params['where'] || @query_params[:where] || {}
  end

  # Validate query parameters are complete
  def valid_query_params?
    errors = []

    # Check query type
    unless valid_query_types.include?(query_type)
      errors << "Invalid query_type: #{query_type}. Must be one of: #{valid_query_types.join(', ')}"
    end

    # Check column name (except for COUNT(*))
    if query_type != 'count' && column_name.blank?
      errors << "Column name is required for #{query_type&.upcase} queries"
    end

    # Validate WHERE conditions
    unless valid_where_conditions?
      errors << "Invalid WHERE conditions. Only simple equality conditions are supported."
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  # Validate WHERE conditions are simple (no subqueries, etc.)
  def valid_where_conditions?
    conditions = where_conditions

    # Empty conditions are valid
    return true if conditions.empty?

    # Must be a hash
    return false unless conditions.is_a?(Hash)

    # Check each condition
    conditions.all? do |column, value|
      # Column must be a string or symbol
      next false unless column.is_a?(String) || column.is_a?(Symbol)

      # Value can be:
      # - Simple scalar (string, number, boolean)
      # - Hash with operator (for ranges, comparisons)
      # - Array (for IN clauses)
      case value
      when Hash
        valid_complex_condition?(value)
      when Array
        value.all? { |v| v.is_a?(String) || v.is_a?(Numeric) || v.is_a?(TrueClass) || v.is_a?(FalseClass) }
      else
        # Simple scalar value
        value.is_a?(String) || value.is_a?(Numeric) || value.is_a?(TrueClass) || value.is_a?(FalseClass) || value.nil?
      end
    end
  end

  # Build SQL for specific dataset
  def build_sql_for_dataset(dataset)
    case query_type
    when 'sum'
      build_sum_query(dataset)
    when 'count'
      build_count_query(dataset)
    when 'avg'
      # For AVG in MPC, we compute SUM (coordinator will divide by total count)
      build_sum_query(dataset)
    else
      raise "Unsupported query type: #{query_type}"
    end
  end

  # Get list of columns referenced in query
  def referenced_columns
    cols = []

    # Add main column
    cols << column_name if column_name.present?

    # Add WHERE clause columns
    cols += where_conditions.keys.map(&:to_s)

    cols.uniq
  end

  # Validate query can run on dataset
  def validate_for_dataset(dataset)
    errors = []

    # Check referenced columns exist
    referenced_columns.each do |col|
      unless dataset.has_column?(col)
        errors << "Column '#{col}' not found in dataset #{dataset.id}"
      end
    end

    # Check column type is numeric for SUM/AVG
    if ['sum', 'avg'].include?(query_type) && column_name.present?
      type = dataset.column_type(column_name)
      unless numeric_types.include?(type.to_s)
        errors << "Column '#{column_name}' must be numeric for #{query_type.upcase}, but is #{type}"
      end
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  private

  def valid_query_types
    %w[sum count avg]
  end

  def valid_complex_condition?(condition)
    return false unless condition.is_a?(Hash)

    operator = condition['operator'] || condition[:operator]
    valid_operators = %w[between gt lt gte lte eq ne in]

    valid_operators.include?(operator.to_s)
  end

  def build_sum_query(dataset)
    raise "Column required for SUM query" if column_name.blank?

    where = WhereClauseBuilder.new(where_conditions, dataset).build

    "SELECT SUM(#{dataset.sanitize_column(column_name)}) as sum FROM #{dataset.table_quoted}#{where}"
  end

  def build_count_query(dataset)
    where = WhereClauseBuilder.new(where_conditions, dataset).build

    "SELECT COUNT(*) as count FROM #{dataset.table_quoted}#{where}"
  end

  def numeric_types
    %w[integer bigint smallint float double decimal numeric real]
  end
end