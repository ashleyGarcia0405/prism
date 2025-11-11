# frozen_string_literal: true

# SchemaValidator validates schema compatibility across multiple datasets
# Used in MPC to ensure all participant datasets have compatible schemas
class SchemaValidator
  attr_reader :datasets

  def initialize(datasets)
    @datasets = Array(datasets)
  end

  # Check if column exists in all datasets
  def column_exists_in_all?(column_name)
    return false if @datasets.empty?

    @datasets.all? { |ds| ds.has_column?(column_name) }
  end

  # Get datasets missing a specific column
  def find_missing_columns(column_name)
    @datasets.reject { |ds| ds.has_column?(column_name) }
  end

  # Get column data types across all datasets
  def column_types(column_name)
    @datasets.map do |ds|
      {
        dataset_id: ds.id,
        organization_id: ds.organization_id,
        organization_name: ds.organization.name,
        column_type: ds.column_type(column_name),
        sql_type: ds.column_info(column_name)&.dig(:sql_type)
      }
    end
  end

  # Check if column types are compatible across all datasets
  def compatible_column_types?(column_name)
    types = @datasets.map { |ds| ds.column_type(column_name) }.compact.uniq

    # All types must be the same
    if types.size == 1
      return true
    end

    # Or all must be compatible numeric types
    if types.all? { |t| numeric_types.include?(t.to_s) }
      return true
    end

    # Or all must be compatible string types
    if types.all? { |t| string_types.include?(t.to_s) }
      return true
    end

    false
  end

  # Get type incompatibilities
  def type_incompatibilities(column_name)
    types = column_types(column_name)

    # Group by type
    grouped = types.group_by { |t| t[:column_type] }

    # If only one group, no incompatibilities
    return [] if grouped.size <= 1

    # Return datasets with different types
    incompatibilities = []
    grouped.each do |type, datasets_with_type|
      incompatibilities << {
        type: type,
        sql_type: datasets_with_type.first[:sql_type],
        datasets: datasets_with_type.map { |d| {
          id: d[:dataset_id],
          organization: d[:organization_name]
        }}
      }
    end

    incompatibilities
  end

  # Suggest alternative column names using fuzzy matching
  def suggest_alternatives(column_name, max_distance: 3)
    alternatives = {}

    @datasets.each do |ds|
      # Find columns with similar names
      similar = ds.columns.select do |col|
        distance = levenshtein_distance(col.downcase, column_name.to_s.downcase)
        distance > 0 && distance <= max_distance
      end

      if similar.any?
        alternatives[ds.id] = {
          dataset_id: ds.id,
          organization: ds.organization.name,
          suggestions: similar
        }
      end
    end

    alternatives
  end

  # Validate full schema compatibility for a query
  def validate_query_compatibility(column_name, query_type)
    errors = []
    warnings = []

    # Check column exists
    unless column_exists_in_all?(column_name)
      missing = find_missing_columns(column_name)
      errors << "Column '#{column_name}' not found in datasets: #{missing.map { |d| "#{d.id} (#{d.organization.name})" }.join(', ')}"

      # Suggest alternatives
      alternatives = suggest_alternatives(column_name)
      if alternatives.any?
        suggestions = alternatives.values.flat_map { |a| a[:suggestions] }.uniq
        warnings << "Did you mean: #{suggestions.join(', ')}?"
      end
    end

    # Check type compatibility
    if column_exists_in_all?(column_name)
      unless compatible_column_types?(column_name)
        incompatibilities = type_incompatibilities(column_name)
        error_msg = "Column '#{column_name}' has incompatible types across datasets:\n"
        incompatibilities.each do |inc|
          orgs = inc[:datasets].map { |d| d[:organization] }.join(', ')
          error_msg += "  - #{inc[:type]} (#{inc[:sql_type]}): #{orgs}\n"
        end
        errors << error_msg.strip
      end

      # Check if type is appropriate for query
      type_error = validate_type_for_query(column_name, query_type)
      errors << type_error if type_error
    end

    {
      valid: errors.empty?,
      errors: errors,
      warnings: warnings
    }
  end

  # Validate column type is appropriate for query type
  def validate_type_for_query(column_name, query_type)
    column_type = @datasets.first.column_type(column_name)
    return nil unless column_type

    case query_type
    when 'sum', 'avg'
      unless numeric_types.include?(column_type.to_s)
        return "Cannot compute #{query_type.upcase} on non-numeric column '#{column_name}' (type: #{column_type})"
      end
    when 'count'
      # COUNT works on any column type
      nil
    else
      "Unknown query type: #{query_type}"
    end
  end

  # Get schema summary for all datasets
  def schema_summary
    @datasets.map do |ds|
      {
        dataset_id: ds.id,
        organization: ds.organization.name,
        table_name: ds.table_name,
        columns: ds.schema_info
      }
    end
  end

  # Find common columns across all datasets
  def common_columns
    return [] if @datasets.empty?

    # Get columns from first dataset
    first_columns = @datasets.first.columns

    # Keep only columns that exist in ALL datasets
    first_columns.select do |col|
      @datasets.all? { |ds| ds.has_column?(col) }
    end
  end

  # Get columns that exist in some but not all datasets
  def partial_columns
    all_columns = @datasets.flat_map(&:columns).uniq

    all_columns.reject do |col|
      column_exists_in_all?(col)
    end
  end

  private

  # List of compatible numeric types
  def numeric_types
    %w[integer bigint smallint float double decimal numeric real]
  end

  # List of compatible string types
  def string_types
    %w[string text varchar char]
  end

  # Calculate Levenshtein distance between two strings
  # Used for fuzzy column name matching
  def levenshtein_distance(str1, str2)
    s = str1.to_s
    t = str2.to_s
    m = s.length
    n = t.length

    return m if n.zero?
    return n if m.zero?

    d = Array.new(m + 1) { Array.new(n + 1) }

    (0..m).each { |i| d[i][0] = i }
    (0..n).each { |j| d[0][j] = j }

    (1..n).each do |j|
      (1..m).each do |i|
        cost = s[i - 1] == t[j - 1] ? 0 : 1
        d[i][j] = [
          d[i - 1][j] + 1,      # deletion
          d[i][j - 1] + 1,      # insertion
          d[i - 1][j - 1] + cost # substitution
        ].min
      end
    end

    d[m][n]
  end
end