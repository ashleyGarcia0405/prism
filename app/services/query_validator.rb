require "pg_query"

module QueryValidator
  ALLOWED_AGGREGATES = %w[COUNT AVG SUM MIN MAX STDDEV].freeze
  MIN_GROUP_SIZE = 25

  class << self
    def validate(sql_string)
      errors = []

      begin
        result = PgQuery.parse(sql_string)

        # Extract the SELECT statement
        select_stmt = extract_select_statement(result)

        unless select_stmt
          errors << "Query must be a SELECT statement"
          return build_response(false, errors)
        end

        # Rule 1: Cannot SELECT *
        errors << "Cannot SELECT * - must use specific aggregates" if selects_star?(select_stmt)

        # Rule 2: Must use aggregate functions
        agg_funcs = find_aggregate_functions(select_stmt)
        errors << "Query must use aggregate functions" if agg_funcs.empty?

        # Rule 3: If there are non-aggregate columns in SELECT, must have GROUP BY
        # (Global aggregates like COUNT(*) or AVG(col) without grouping are allowed)
        has_group_by = has_group_by?(select_stmt)
        has_non_agg_columns = has_non_aggregate_columns?(select_stmt, agg_funcs)

        if has_non_agg_columns && !has_group_by
          errors << "Queries with grouping columns require GROUP BY clause"
        end

        # Rule 4: Must have HAVING COUNT(*) >= MIN_GROUP_SIZE for k-anonymity when grouping
        if has_group_by && !has_valid_having_clause?(select_stmt)
          errors << "Must include HAVING COUNT(*) >= #{MIN_GROUP_SIZE} for k-anonymity"
        end

        # Rule 5: No subqueries (timing attacks)
        errors << "Subqueries are not allowed" if has_subquery?(select_stmt)

        # Rule 6: Only allowed aggregate functions
        invalid_funcs = agg_funcs.reject { |f| ALLOWED_AGGREGATES.include?(f.upcase) }
        if invalid_funcs.any?
          errors << "Only these aggregates are allowed: #{ALLOWED_AGGREGATES.join(', ')}"
        end

        return build_response(false, errors) if errors.any?

        # Success - estimate epsilon
        estimated_epsilon = estimate_epsilon(agg_funcs)

        {
          valid: true,
          estimated_epsilon: estimated_epsilon
        }

      rescue PgQuery::ParseError => e
        errors << "Invalid SQL syntax: #{e.message}"
        build_response(false, errors)
      end
    end

    private

    def build_response(valid, errors)
      {
        valid: valid,
        errors: errors,
        estimated_epsilon: 0
      }
    end

    def extract_select_statement(result)
      return nil unless result.tree.stmts&.any?

      raw_stmt = result.tree.stmts.first
      return nil unless raw_stmt.stmt

      raw_stmt.stmt.select_stmt
    end

    def selects_star?(select_stmt)
      return false unless select_stmt.target_list&.any?

      select_stmt.target_list.any? do |target_node|
        next unless target_node.res_target

        res_target = target_node.res_target
        next unless res_target.val&.column_ref

        column_ref = res_target.val.column_ref
        column_ref.fields.any? { |field| field.a_star }
      end
    end

    def find_aggregate_functions(select_stmt)
      agg_funcs = []

      # Check target list for aggregates
      if select_stmt.target_list&.any?
        select_stmt.target_list.each do |target_node|
          next unless target_node.res_target

          res_target = target_node.res_target
          next unless res_target.val&.func_call

          func_call = res_target.val.func_call
          func_name = extract_function_name(func_call)
          agg_funcs << func_name if func_name
        end
      end

      agg_funcs
    end

    def extract_function_name(func_call)
      return nil unless func_call.funcname&.any?

      func_call.funcname.map { |name_node| name_node.string.sval }.join(".")
    end

    def has_group_by?(select_stmt)
      select_stmt.group_clause&.any?
    end

    def has_non_aggregate_columns?(select_stmt, agg_funcs)
      # Check if SELECT list has columns that are not aggregates
      return false unless select_stmt.target_list&.any?

      non_agg_count = 0

      select_stmt.target_list.each do |target_node|
        next unless target_node.res_target

        res_target = target_node.res_target
        next unless res_target.val

        # If it's a column reference (not a function), it's a non-aggregate
        if res_target.val.column_ref
          non_agg_count += 1
        end
      end

      non_agg_count > 0
    end

    def has_valid_having_clause?(select_stmt)
      return false unless select_stmt.having_clause

      # Look for: COUNT(*) >= 25
      check_having_condition(select_stmt.having_clause)
    end

    def check_having_condition(node)
      return false unless node

      # Handle A_Expr nodes (comparisons)
      if node.a_expr
        expr = node.a_expr
        operator = expr.name&.first&.string&.sval

        # Check if it's >= or >
        return false unless [ ">=", ">" ].include?(operator)

        # Check left side is COUNT(*)
        if expr.lexpr&.func_call
          left_func = expr.lexpr.func_call
          func_name = extract_function_name(left_func)
          is_count = func_name&.upcase == "COUNT"

          # Check right side is >= MIN_GROUP_SIZE
          right_val = expr.rexpr&.a_const&.ival&.ival

          return is_count && right_val && right_val >= MIN_GROUP_SIZE
        end
      end

      # Handle BoolExpr nodes (AND/OR)
      if node.bool_expr
        args = node.bool_expr.args
        return args&.any? { |arg| check_having_condition(arg) }
      end

      false
    end

    def has_subquery?(select_stmt)
      # Check target list for subqueries (scalar subqueries in SELECT)
      if select_stmt.target_list&.any?
        select_stmt.target_list.each do |target_node|
          if target_node.res_target&.val
            return true if contains_subselect?(target_node.res_target.val)
          end
        end
      end

      # Check FROM clause for subqueries
      if select_stmt.from_clause&.any?
        return true if select_stmt.from_clause.any? { |from_node| from_node.range_subselect }
      end

      # Check WHERE clause recursively
      if select_stmt.where_clause
        return true if contains_subselect?(select_stmt.where_clause)
      end

      false
    end

    def contains_subselect?(node)
      return false unless node

      # Check if this node is a SubLink
      return true if node.sub_link

      # Recursively check child nodes using protobuf reflection
      node.class.descriptor.each do |field|
        value = node.send(field.name)
        next if value.nil?

        if value.is_a?(Array)
          return true if value.any? { |item| contains_subselect?(item) }
        elsif value.respond_to?(:sub_link)
          return true if contains_subselect?(value)
        end
      end

      false
    end

    def estimate_epsilon(agg_funcs)
      epsilon = 0.0

      agg_funcs.each do |func|
        case func.upcase
        when "COUNT", "MIN", "MAX"
          epsilon += 0.1
        when "AVG", "SUM", "STDDEV"
          epsilon += 0.5
        end
      end

      [ epsilon, 0.1 ].max # Minimum epsilon
    end
  end
end
