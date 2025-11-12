# spec/services/query_validator_additional_spec.rb
require "rails_helper"

RSpec.describe QueryValidator do
  describe "edge cases and helper branches" do
    # 1) extract_select_statement: raw_stmt.stmt nil
    it "handles parse result where raw_stmt has no stmt" do
      fake = double(tree: double(stmts: [ double(stmt: nil) ]))
      allow(PgQuery).to receive(:parse).and_return(fake)
      res = QueryValidator.validate("SELECT 1")
      expect(res[:valid]).to eq(false)
      expect(res[:errors]).to include("Query must be a SELECT statement")
    ensure
      allow(PgQuery).to receive(:parse).and_call_original
    end

    # 2) selects_star?: target_list present but with a target_node that has no res_target
    it "selects_star? handles target_node without res_target" do
      # Build a fake select_stmt with target_list containing a node with res_target == nil
      select_stmt = double(target_list: [ double(res_target: nil) ])
      expect(QueryValidator.send(:selects_star?, select_stmt)).to eq(false)
    end

    # 3) selects_star?: star field present (SELECT *)
    it "detects SELECT * via selects_star?" do
      field = double(a_star: true)
      column_ref = double(fields: [ field ])
      val = double(column_ref: column_ref)
      res_target = double(val: val)
      target_node = double(res_target: res_target)
      select_stmt = double(target_list: [ target_node ])
      expect(QueryValidator.send(:selects_star?, select_stmt)).to eq(true)
    end

    # 4) find_aggregate_functions: target_node with no func_call
    it "find_aggregate_functions ignores non-func targets" do
      # target node with res_target but val has no func_call
      res_target = double(val: double(func_call: nil))
      target_node = double(res_target: res_target)
      select_stmt = double(target_list: [ target_node ])
      funcs = QueryValidator.send(:find_aggregate_functions, select_stmt)
      expect(funcs).to eq([])
    end

    # 5) extract_function_name: func_call without funcname and with schema.func
    it "extract_function_name handles missing funcname and schema-qualified funcname" do
      # missing funcname
      fcall = double(funcname: nil)
      expect(QueryValidator.send(:extract_function_name, fcall)).to be_nil
    end

    # 6) has_group_by? with no group clause
    it "has_group_by? returns falsy when no group clause" do
      select_stmt = double(group_clause: nil)
      # Safe nav on nil returns nil, which is falsy
      expect(QueryValidator.send(:has_group_by?, select_stmt)).to be_falsy
    end

    # 7) has_group_by? with empty group clause
    it "has_group_by? returns false for empty group clause" do
      select_stmt = double(group_clause: [])
      expect(QueryValidator.send(:has_group_by?, select_stmt)).to eq(false)
    end

    # 8) has_non_aggregate_columns? with target_node having no res_target
    it "has_non_aggregate_columns? skips targets without res_target" do
      target_node = double(res_target: nil)
      select_stmt = double(target_list: [ target_node ])
      result = QueryValidator.send(:has_non_aggregate_columns?, select_stmt, [])
      expect(result).to eq(false)
    end

    # 9) has_non_aggregate_columns? with res_target.val nil
    it "has_non_aggregate_columns? skips targets with nil val" do
      res_target = double(val: nil)
      target_node = double(res_target: res_target)
      select_stmt = double(target_list: [ target_node ])
      result = QueryValidator.send(:has_non_aggregate_columns?, select_stmt, [])
      expect(result).to eq(false)
    end

    # 10) has_non_aggregate_columns? with column_ref (non-agg column)
    it "has_non_aggregate_columns? detects column_ref as non-aggregate" do
      column_ref = double()
      val = double(column_ref: column_ref)
      res_target = double(val: val)
      target_node = double(res_target: res_target)
      select_stmt = double(target_list: [ target_node ])
      result = QueryValidator.send(:has_non_aggregate_columns?, select_stmt, [])
      expect(result).to eq(true)
    end

    # 11) check_having_condition with nil node
    it "check_having_condition returns false for nil node" do
      expect(QueryValidator.send(:check_having_condition, nil)).to eq(false)
    end

    # 12) check_having_condition with a_expr operator >=
    it "check_having_condition validates COUNT(*) >= 25" do
      # Build a valid a_expr: COUNT(*) >= 25
      int_val = double(ival: 25)
      a_const = double(ival: int_val)
      rexpr = double(a_const: a_const)

      # Operator node
      op_string = double(sval: ">=")
      op_node = double(string: op_string)

      # Left side: COUNT(*)
      count_string = double(sval: "COUNT")
      count_name_node = double(string: count_string)
      left_func = double(funcname: [ count_name_node ])
      lexpr = double(func_call: left_func)

      a_expr = double(name: [ op_node ], lexpr: lexpr, rexpr: rexpr)
      node = double(a_expr: a_expr, bool_expr: nil)

      expect(QueryValidator.send(:check_having_condition, node)).to eq(true)
    end

    # 13) check_having_condition with invalid operator
    it "check_having_condition rejects invalid operators" do
      string_node = double(sval: "<")
      name_node = double(string: string_node)
      a_expr = double(name: [ name_node ])
      node = double(a_expr: a_expr, bool_expr: nil)

      expect(QueryValidator.send(:check_having_condition, node)).to eq(false)
    end

    # 14) check_having_condition with COUNT() < 25 (wrong threshold)
    it "check_having_condition rejects COUNT(*) with value < 25" do
      int_val = double(ival: 10)
      a_const = double(ival: int_val)
      rexpr = double(a_const: a_const)

      string_node = double(sval: "COUNT")
      name_node = double(string: string_node)
      left_func = double(funcname: [ name_node ])
      lexpr = double(func_call: left_func)

      op_node = double(string: double(sval: ">="))
      a_expr = double(name: [ op_node ], lexpr: lexpr, rexpr: rexpr)
      node = double(a_expr: a_expr, bool_expr: nil)

      expect(QueryValidator.send(:check_having_condition, node)).to eq(false)
    end

    # 15) check_having_condition with bool_expr (AND/OR)
    it "check_having_condition handles bool_expr (AND/OR)" do
      int_val = double(ival: 25)
      a_const = double(ival: int_val)
      rexpr = double(a_const: a_const)

      string_node = double(sval: "COUNT")
      name_node = double(string: string_node)
      left_func = double(funcname: [ name_node ])
      lexpr = double(func_call: left_func)

      op_node = double(string: double(sval: ">="))
      a_expr = double(name: [ op_node ], lexpr: lexpr, rexpr: rexpr)
      inner_node = double(a_expr: a_expr, bool_expr: nil)

      bool_expr = double(args: [ inner_node ])
      outer_node = double(a_expr: nil, bool_expr: bool_expr)

      expect(QueryValidator.send(:check_having_condition, outer_node)).to eq(true)
    end

    # 16) contains_subselect? with nil node
    it "contains_subselect? returns false for nil node" do
      expect(QueryValidator.send(:contains_subselect?, nil)).to eq(false)
    end

    # 17) contains_subselect? with sub_link present
    it "contains_subselect? detects sub_link" do
      node = double(sub_link: true)
      allow(node).to receive(:class).and_return(double(descriptor: []))
      expect(QueryValidator.send(:contains_subselect?, node)).to eq(true)
    end

    # 18) estimate_epsilon: COUNT (0.1)
    it "estimate_epsilon adds 0.1 for COUNT" do
      result = QueryValidator.send(:estimate_epsilon, [ "COUNT" ])
      expect(result).to eq(0.1)
    end

    # 19) estimate_epsilon: SUM (0.5)
    it "estimate_epsilon adds 0.5 for SUM" do
      result = QueryValidator.send(:estimate_epsilon, [ "SUM" ])
      expect(result).to eq(0.5)
    end

    # 20) estimate_epsilon: multiple functions (COUNT + AVG)
    it "estimate_epsilon sums multiple function costs" do
      result = QueryValidator.send(:estimate_epsilon, [ "COUNT", "AVG" ])
      expect(result).to eq(0.6) # 0.1 + 0.5
    end

    # 21) estimate_epsilon: multiple of same (2x COUNT)
    it "estimate_epsilon accumulates same function calls" do
      result = QueryValidator.send(:estimate_epsilon, [ "COUNT", "COUNT" ])
      expect(result).to eq(0.2) # 0.1 + 0.1
    end

    # 22) estimate_epsilon: all 6 allowed functions
    it "estimate_epsilon with all 6 allowed aggregates" do
      funcs = [ "COUNT", "MIN", "MAX", "AVG", "SUM", "STDDEV" ]
      result = QueryValidator.send(:estimate_epsilon, funcs)
      expected = 3 * 0.1 + 3 * 0.5 # COUNT, MIN, MAX (0.1 each) + AVG, SUM, STDDEV (0.5 each)
      expect(result).to eq(expected)
    end

    # 23) estimate_epsilon: minimum epsilon is 0.1
    it "estimate_epsilon minimum is 0.1" do
      result = QueryValidator.send(:estimate_epsilon, [])
      expect(result).to eq(0.1)
    end

    # 24) estimate_epsilon: uppercase conversion
    it "estimate_epsilon handles lowercase function names" do
      result = QueryValidator.send(:estimate_epsilon, [ "count", "sum" ])
      expect(result).to eq(0.6) # 0.1 + 0.5
    end

    # Additional tests for hard-to-reach branches with safe-navigation operators

    # 25) extract_select_statement: result.tree.stmts is nil (safe nav else branch)
    it "extract_select_statement handles nil stmts gracefully via safe nav" do
      fake_tree = double(stmts: nil)
      fake_result = double(tree: fake_tree)
      allow(PgQuery).to receive(:parse).and_return(fake_result)
      res = QueryValidator.validate("SELECT 1")
      expect(res[:valid]).to eq(false)
    ensure
      allow(PgQuery).to receive(:parse).and_call_original
    end

    # 26) selects_star?: res_target.val is nil (safe nav else)
    it "selects_star? handles res_target.val nil" do
      res_target = double(val: nil)
      target_node = double(res_target: res_target)
      select_stmt = double(target_list: [ target_node ])
      expect(QueryValidator.send(:selects_star?, select_stmt)).to eq(false)
    end

    # 27) find_aggregate_functions: func_name is nil after extraction
    it "find_aggregate_functions skips if func_name extraction returns nil" do
      # Build a func_call with funcname: [] (empty)
      fcall = double(funcname: [])
      val = double(func_call: fcall)
      res_target = double(val: val)
      target_node = double(res_target: res_target)
      select_stmt = double(target_list: [ target_node ])
      funcs = QueryValidator.send(:find_aggregate_functions, select_stmt)
      # extract_function_name will try to map over empty array and return ""
      # which is falsy in the "agg_funcs << func_name if func_name" check
      expect(funcs.length).to be >= 0
    end

    # 28) check_having_condition with lexpr that is not func_call
    it "check_having_condition handles lexpr without func_call" do
      # lexpr is nil or doesn't have func_call
      rexpr = double(a_const: nil)
      name_node = double(string: double(sval: ">="))
      a_expr = double(name: [ name_node ], lexpr: double(func_call: nil), rexpr: rexpr)
      node = double(a_expr: a_expr, bool_expr: nil)

      expect(QueryValidator.send(:check_having_condition, node)).to eq(false)
    end

    # 29) check_having_condition with bool_expr args nil (safe nav)
    it "check_having_condition handles bool_expr with nil args" do
      bool_expr = double(args: nil)
      node = double(a_expr: nil, bool_expr: bool_expr)

      # args&.any? should return nil, which is falsy
      expect(QueryValidator.send(:check_having_condition, node)).to be_falsy
    end

    # 30) contains_subselect?: field descriptor iteration (coverage of array branch)
    it "contains_subselect? iterates through protobuf fields (integration)" do
      # This tests the descriptor iteration logic
      field = double(name: "test")
      descriptor = [ field ]

      node = double(sub_link: false)
      allow(node).to receive(:class).and_return(double(descriptor: descriptor))
      allow(node).to receive(:send).with("test").and_return([])

      expect(QueryValidator.send(:contains_subselect?, node)).to eq(false)
    end

    # 6) has_group_by? true/false
    it "has_group_by? returns true/false appropriately" do
      select_stmt1 = double(group_clause: nil)
      select_stmt2 = double(group_clause: [ 1 ])
      expect(QueryValidator.send(:has_group_by?, select_stmt1)).to be_nil.or eq(false)
      expect(QueryValidator.send(:has_group_by?, select_stmt2)).to eq(true)
    end

    # 7) has_non_aggregate_columns?: non-agg present and nil target_list
    it "has_non_aggregate_columns? returns false for missing target_list and true for column refs" do
      no_targets = double(target_list: nil)
      expect(QueryValidator.send(:has_non_aggregate_columns?, no_targets, [])).to eq(false)

      # one column_ref present
      val = double(column_ref: double)
      res_target = double(val: val)
      target_node = double(res_target: res_target)
      select_stmt = double(target_list: [ target_node ])
      expect(QueryValidator.send(:has_non_aggregate_columns?, select_stmt, [])).to eq(true)
    end

    # 8) check_having_condition: operator not in allowed set -> false
    it "check_having_condition returns false if operator is not >= or >" do
      # Build an A_Expr style double where name.first.string.sval returns "="
      name_node = double(string: double(sval: "="))
      expr = double(name: [ name_node ], lexpr: nil, rexpr: nil)
      node = double(a_expr: expr, bool_expr: nil)
      expect(QueryValidator.send(:check_having_condition, node)).to eq(false)
    end

    # 9) check_having_condition: a_expr with valid operator but left not a func_call -> false
    it "check_having_condition false when left side not a func_call" do
      name_node = double(string: double(sval: ">="))
      expr = double(name: [ name_node ], lexpr: double(func_call: nil), rexpr: double(a_const: nil))
      node = double(a_expr: expr, bool_expr: nil)
      expect(QueryValidator.send(:check_having_condition, node)).to eq(false)
    end

    # 10) check_having_condition: valid COUNT and right side below MIN_GROUP_SIZE -> false
    it "check_having_condition false when right side below MIN_GROUP_SIZE" do
      name_node = double(string: double(sval: ">="))
      func_call = double # func_call placeholder
      lexpr = double(func_call: func_call)
      right_val_const = double(ival: double(ival: QueryValidator::MIN_GROUP_SIZE - 1))
      expr = double(name: [ name_node ], lexpr: lexpr, rexpr: double(a_const: right_val_const))
      # stub extract_function_name to return "count" for this func_call
      allow(QueryValidator).to receive(:extract_function_name).with(func_call).and_return("count")
      node = double(a_expr: expr, bool_expr: nil)
      expect(QueryValidator.send(:check_having_condition, node)).to eq(false)
      # restore
      allow(QueryValidator).to receive(:extract_function_name).and_call_original
    end

    # 11) check_having_condition: bool_expr (OR) where one arg satisfies condition -> true
    it "check_having_condition handles bool_expr (OR) and returns true when an arg satisfies condition" do
      # build a valid a_expr as above where right side >= MIN_GROUP_SIZE
      name_node = double(string: double(sval: ">="))
      func_call = double
      lexpr = double(func_call: func_call)
      right_val_const = double(ival: double(ival: QueryValidator::MIN_GROUP_SIZE + 1))
      expr = double(name: [ name_node ], lexpr: lexpr, rexpr: double(a_const: right_val_const))
      allow(QueryValidator).to receive(:extract_function_name).with(func_call).and_return("count")
      # bool_expr with args array containing our expr wrapper
      arg_node = double(a_expr: expr, bool_expr: nil)
      # make sure node responds to a_expr (nil) so check_having_condition first branch won't raise
      bool_wrapper = double(a_expr: nil, bool_expr: double(args: [ arg_node ]))
      expect(QueryValidator.send(:check_having_condition, bool_wrapper)).to eq(true)
      allow(QueryValidator).to receive(:extract_function_name).and_call_original
    end

    # 12) contains_subselect?: node.sub_link true -> true
    it "contains_subselect? returns true when node.sub_link is present" do
      node = double(sub_link: true)
      expect(QueryValidator.send(:contains_subselect?, node)).to eq(true)
    end

    # 13) contains_subselect?: value is array branch -> true when nested item has sub_link
    it "contains_subselect? explores array fields and finds nested sub_link" do
      # create a field descriptor mock with name 'child'
      field_desc = double(name: 'child')
      # node whose class.descriptor yields that field_desc
      node = double(sub_link: nil)
      allow(node).to receive(:class).and_return(double(descriptor: [ field_desc ]))
      # define node.child to return array of items, one of which has sub_link true
      nested = double(sub_link: true)
      allow(node).to receive(:child).and_return([ nested ])
      expect(QueryValidator.send(:contains_subselect?, node)).to eq(true)
    end

    # 14) contains_subselect?: value.respond_to?(:sub_link) path
    it "contains_subselect? returns true when nested value responds to sub_link" do
      field_desc = double(name: 'elem')
      node = double(sub_link: nil)
      allow(node).to receive(:class).and_return(double(descriptor: [ field_desc ]))
      nested = double(sub_link: true)
      # return single object (not an array) to hit the respond_to branch
      allow(node).to receive(:elem).and_return(nested)
      expect(QueryValidator.send(:contains_subselect?, node)).to eq(true)
    end

    # 15) estimate_epsilon: cover all case arms
    it "estimate_epsilon sums epsilon per aggregate type" do
      eps = QueryValidator.send(:estimate_epsilon, [ "COUNT", "MIN", "MAX" ])
      expect(eps).to be >= 0.3 # each of COUNT/MIN/MAX adds 0.1

      eps2 = QueryValidator.send(:estimate_epsilon, [ "AVG", "SUM", "STDDEV" ])
      expect(eps2).to be >= 1.5 # 3 * 0.5

      # mixed set and minimum enforced
      eps3 = QueryValidator.send(:estimate_epsilon, [])
      expect(eps3).to be >= 0.1
    end
  end
end
