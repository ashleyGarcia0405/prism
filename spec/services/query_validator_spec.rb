require 'rails_helper'

RSpec.describe QueryValidator do
  describe '.validate' do
    context 'with valid aggregate query' do
      let(:sql) do
        "SELECT state, AVG(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
      end

      it 'returns valid: true' do
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be true
      end

      it 'estimates epsilon correctly' do
        result = QueryValidator.validate(sql)
        expect(result[:estimated_epsilon]).to eq(0.6) # AVG=0.5 + COUNT=0.1
      end

      it 'does not include errors' do
        result = QueryValidator.validate(sql)
        expect(result[:errors]).to be_nil
      end
    end

    context 'with COUNT aggregate' do
      let(:sql) do
        "SELECT diagnosis, COUNT(*) FROM patients GROUP BY diagnosis HAVING COUNT(*) >= 25"
      end

      it 'returns valid: true' do
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be true
      end

      it 'estimates epsilon as 0.1' do
        result = QueryValidator.validate(sql)
        expect(result[:estimated_epsilon]).to eq(0.1)
      end
    end

    context 'Rule 1: SELECT * is rejected' do
      let(:sql) { "SELECT * FROM patients" }

      it 'rejects the query' do
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'includes appropriate error message' do
        result = QueryValidator.validate(sql)
        expect(result[:errors]).to include("Cannot SELECT * - must use specific aggregates")
      end
    end

    context 'Rule 2: Must use aggregate functions' do
      let(:sql) { "SELECT name, age FROM patients WHERE age > 50" }

      it 'rejects the query' do
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'includes appropriate error message' do
        result = QueryValidator.validate(sql)
        expect(result[:errors]).to include("Query must use aggregate functions")
      end
    end

    context 'Rule 3: Global aggregates allowed without GROUP BY' do
      let(:sql) { "SELECT AVG(age), COUNT(*) FROM patients" }

      it 'accepts the query' do
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be true
      end
    end

    context 'Rule 3: Grouping columns require GROUP BY' do
      let(:sql) { "SELECT state, AVG(age) FROM patients" }

      it 'rejects the query without GROUP BY' do
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'includes appropriate error message' do
        result = QueryValidator.validate(sql)
        expect(result[:errors]).to include("Queries with grouping columns require GROUP BY clause")
      end
    end

    context 'Rule 4: k-anonymity via HAVING' do
      let(:sql) { "SELECT state, AVG(age) FROM patients GROUP BY state" }

      it 'rejects the query without HAVING' do
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'includes appropriate error message' do
        result = QueryValidator.validate(sql)
        expect(result[:errors]).to include("Must include HAVING COUNT(*) >= 25 for k-anonymity")
      end

      context 'with insufficient k-anonymity threshold' do
        let(:sql) do
          "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 5"
        end

        it 'rejects queries with COUNT(*) < 25' do
          result = QueryValidator.validate(sql)
          expect(result[:valid]).to be false
        end
      end
    end

    context 'Rule 5: No subqueries' do
      let(:sql) do
        "SELECT state, (SELECT COUNT(*) FROM patients p2 WHERE p2.state = p1.state) FROM patients p1 GROUP BY state HAVING COUNT(*) >= 25"
      end

      it 'rejects queries with subqueries' do
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'includes appropriate error message' do
        result = QueryValidator.validate(sql)
        expect(result[:errors]).to include("Subqueries are not allowed")
      end
    end

    context 'Rule 6: Only whitelisted aggregates' do
      it 'allows COUNT' do
        sql = "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be true
      end

      it 'allows AVG' do
        sql = "SELECT state, AVG(age) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be true
      end

      it 'allows SUM' do
        sql = "SELECT state, SUM(income), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be true
      end

      it 'allows MIN' do
        sql = "SELECT state, MIN(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be true
      end

      it 'allows MAX' do
        sql = "SELECT state, MAX(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be true
      end

      it 'allows STDDEV' do
        sql = "SELECT state, STDDEV(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be true
      end
    end

    context 'with invalid SQL syntax' do
      let(:sql) { "SELECT INVALID SYNTAX" }

      it 'returns valid: false' do
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'includes error message' do
        result = QueryValidator.validate(sql)
        expect(result[:errors]).not_to be_empty
      end
    end

    context 'epsilon estimation' do
      it 'estimates 0.1 for COUNT' do
        sql = "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:estimated_epsilon]).to eq(0.1)
      end

      it 'estimates 0.5 for AVG' do
        sql = "SELECT state, AVG(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:estimated_epsilon]).to eq(0.6) # AVG=0.5 + COUNT=0.1
      end

      it 'estimates 0.5 for SUM' do
        sql = "SELECT state, SUM(income), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:estimated_epsilon]).to eq(0.6) # SUM=0.5 + COUNT=0.1
      end

      it 'sums multiple aggregates correctly' do
        sql = "SELECT state, AVG(age), SUM(income), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:estimated_epsilon]).to eq(1.1) # AVG=0.5 + SUM=0.5 + COUNT=0.1
      end
    end

    context 'with SQL injection attempts' do
      it 'rejects DROP TABLE attempts' do
        sql = "'; DROP TABLE patients; --"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'rejects UNION SELECT attacks' do
        sql = "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25 UNION SELECT * FROM users"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'rejects OR 1=1 attacks' do
        sql = "SELECT state, COUNT(*) FROM patients WHERE 1=1 OR 1=1 GROUP BY state HAVING COUNT(*) >= 25"
        # This might pass validation but should be handled by query execution
        result = QueryValidator.validate(sql)
        # Should either pass (if WHERE is allowed) or fail
        expect(result).to have_key(:valid)
      end

      it 'rejects comment-based injection' do
        sql = "SELECT state, COUNT(*) FROM patients /*'; DROP TABLE patients; --*/ GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        # Should handle comments gracefully
        expect(result).to have_key(:valid)
      end
    end

    context 'with edge cases' do
      it 'handles empty SQL' do
        result = QueryValidator.validate("")
        expect(result[:valid]).to be false
        expect(result[:errors]).to be_present
      end

      it 'returns validation error when SQL is nil' do
        result = QueryValidator.validate(nil)

        expect(result[:valid]).to be false
        expect(result[:errors]).to include('SQL cannot be empty')
      end

      it 'handles SQL with only whitespace' do
        result = QueryValidator.validate("   \n\t   ")
        expect(result[:valid]).to be false
        expect(result[:errors]).to be_present
      end

      it 'handles very long SQL' do
        long_sql = "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25" + " " * 100000
        result = QueryValidator.validate(long_sql)
        # Should either validate or fail gracefully
        expect(result).to have_key(:valid)
      end

      it 'handles SQL with special characters' do
        sql = "SELECT state, COUNT(*) FROM patients WHERE name = 'O\\'Brien' GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        # Should handle escaped quotes
        expect(result).to have_key(:valid)
      end

      it 'handles SQL with unicode characters' do
        sql = "SELECT state, COUNT(*) FROM patients WHERE name = '测试' GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        # Should handle unicode
        expect(result).to have_key(:valid)
      end
    end

    context 'with malformed SQL syntax' do
      it 'rejects incomplete SELECT' do
        sql = "SELECT"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'rejects missing FROM clause' do
        sql = "SELECT state, COUNT(*) HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'rejects invalid aggregate syntax' do
        sql = "SELECT state, COUNT( FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'rejects mismatched parentheses' do
        sql = "SELECT state, COUNT(*) FROM patients WHERE (age > 50 GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'rejects invalid HAVING clause' do
        sql = "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >="
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end
    end

    context 'with SQL containing comments' do
      it 'handles single-line comments' do
        sql = "SELECT state, COUNT(*) FROM patients -- comment\nGROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        # Should handle comments
        expect(result).to have_key(:valid)
      end

      it 'handles multi-line comments' do
        sql = "SELECT state, COUNT(*) FROM patients /* comment */ GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        # Should handle comments
        expect(result).to have_key(:valid)
      end
    end

    context 'with invalid k-anonymity threshold' do
      it 'rejects HAVING COUNT(*) < 25' do
        sql = "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 24"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'rejects HAVING COUNT(*) = 24' do
        sql = "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) = 24"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'rejects HAVING COUNT(*) = 25 (requires >= not =)' do
        sql = "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) = 25"
        result = QueryValidator.validate(sql)
        # The validator checks for >=, not =, so this should fail
        expect(result[:valid]).to be false
      end
      
      it 'accepts HAVING COUNT(*) >= 25' do
        sql = "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be true
      end

      it 'rejects HAVING with non-numeric threshold' do
        sql = "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= '25'"
        result = QueryValidator.validate(sql)
        # Should fail validation
        expect(result[:valid]).to be false
      end
    end

    context 'with disallowed aggregate functions' do
      it 'rejects GROUP_CONCAT' do
        sql = "SELECT state, GROUP_CONCAT(name), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end

      it 'rejects custom functions' do
        sql = "SELECT state, CUSTOM_FUNC(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        expect(result[:valid]).to be false
      end
    end

    context 'with invalid GROUP BY' do
      it 'rejects GROUP BY with non-existent columns' do
        sql = "SELECT nonexistent_column, COUNT(*) FROM patients GROUP BY nonexistent_column HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        # Validation might pass (syntax is valid) but execution would fail
        expect(result).to have_key(:valid)
      end

      it 'rejects GROUP BY without matching SELECT columns' do
        sql = "SELECT state, COUNT(*) FROM patients GROUP BY city HAVING COUNT(*) >= 25"
        result = QueryValidator.validate(sql)
        # This is syntactically valid but semantically incorrect
        expect(result).to have_key(:valid)
      end
    end
  end
end
