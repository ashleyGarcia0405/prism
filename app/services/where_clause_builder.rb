# frozen_string_literal: true

# WhereClauseBuilder builds safe WHERE clauses for SQL queries
# Handles simple equality, ranges, comparisons, and IN clauses
class WhereClauseBuilder
  attr_reader :conditions, :dataset

  def initialize(conditions, dataset)
    @conditions = conditions || {}
    @dataset = dataset
  end

  # Build WHERE clause from conditions
  def build
    return '' if @conditions.empty?

    clauses = @conditions.map do |column, condition|
      build_condition(column, condition)
    end

    " WHERE #{clauses.join(' AND ')}"
  end

  private

  def build_condition(column, condition)
    safe_column = @dataset.sanitize_column(column)

    case condition
    when Hash
      # Complex condition: {operator: 'between', min: 20, max: 65}
      build_complex_condition(safe_column, condition)
    when Array
      # IN condition: ['diabetes', 'hypertension']
      build_in_condition(safe_column, condition)
    when NilClass
      # NULL check
      "#{safe_column} IS NULL"
    else
      # Simple equality
      "#{safe_column} = #{@dataset.sanitize_value(condition)}"
    end
  end

  def build_complex_condition(column, condition)
    operator = (condition['operator'] || condition[:operator]).to_s

    case operator
    when 'between'
      min_val = @dataset.sanitize_value(condition['min'] || condition[:min])
      max_val = @dataset.sanitize_value(condition['max'] || condition[:max])
      "#{column} BETWEEN #{min_val} AND #{max_val}"

    when 'gt'
      value = @dataset.sanitize_value(condition['value'] || condition[:value])
      "#{column} > #{value}"

    when 'lt'
      value = @dataset.sanitize_value(condition['value'] || condition[:value])
      "#{column} < #{value}"

    when 'gte'
      value = @dataset.sanitize_value(condition['value'] || condition[:value])
      "#{column} >= #{value}"

    when 'lte'
      value = @dataset.sanitize_value(condition['value'] || condition[:value])
      "#{column} <= #{value}"

    when 'eq'
      value = @dataset.sanitize_value(condition['value'] || condition[:value])
      "#{column} = #{value}"

    when 'ne'
      value = @dataset.sanitize_value(condition['value'] || condition[:value])
      "#{column} != #{value}"

    when 'in'
      values = condition['values'] || condition[:values]
      build_in_condition(column, values)

    when 'not_in'
      values = condition['values'] || condition[:values]
      safe_values = values.map { |v| @dataset.sanitize_value(v) }.join(', ')
      "#{column} NOT IN (#{safe_values})"

    when 'is_null'
      "#{column} IS NULL"

    when 'is_not_null'
      "#{column} IS NOT NULL"

    when 'like'
      pattern = @dataset.sanitize_value(condition['pattern'] || condition[:pattern])
      "#{column} LIKE #{pattern}"

    when 'ilike'
      # Case-insensitive LIKE (PostgreSQL)
      pattern = @dataset.sanitize_value(condition['pattern'] || condition[:pattern])
      "#{column} ILIKE #{pattern}"

    else
      raise "Unsupported operator: #{operator}"
    end
  end

  def build_in_condition(column, values)
    return "#{column} IN (NULL)" if values.empty?

    safe_values = values.map { |v| @dataset.sanitize_value(v) }.join(', ')
    "#{column} IN (#{safe_values})"
  end
end