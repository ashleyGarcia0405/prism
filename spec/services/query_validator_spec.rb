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

    it "returns parse error message for malformed SQL" do
      res = QueryValidator.validate("SELEC FROM")
      expect(res[:valid]).to eq(false)
      expect(res[:errors].join).to match(/Invalid SQL syntax/i)
    end

    it "rejects non-select statements" do
      res = QueryValidator.validate("INSERT INTO t VALUES (1)")
      expect(res[:valid]).to eq(false)
      expect(res[:errors]).to include("Query must be a SELECT statement")
    end

    it "rejects SELECT *" do
      res = QueryValidator.validate("SELECT * FROM people")
      expect(res[:valid]).to eq(false)
      expect(res[:errors].join).to match(/Cannot SELECT \*/i)
    end

    it "requires aggregate functions" do
      res = QueryValidator.validate("SELECT id, name FROM people")
      expect(res[:valid]).to eq(false)
      expect(res[:errors].join).to match(/Query must use aggregate functions/)
    end

    it "flags non-aggregate columns without GROUP BY" do
      res = QueryValidator.validate("SELECT id, COUNT(*) FROM people")
      expect(res[:valid]).to eq(false)
      expect(res[:errors].join).to match(/require GROUP BY/i)
    end

    it "requires HAVING with COUNT >= MIN_GROUP_SIZE when grouping" do
      res = QueryValidator.validate("SELECT id, COUNT(*) FROM people GROUP BY id")
      expect(res[:valid]).to eq(false)
      expect(res[:errors].join).to match(/Must include HAVING COUNT\(\*\) >= #{QueryValidator::MIN_GROUP_SIZE}/)
    end

    it "accepts GROUP BY when HAVING COUNT >= MIN_GROUP_SIZE is present (>= operator)" do
      res = QueryValidator.validate("SELECT id, COUNT(*) FROM people GROUP BY id HAVING COUNT(*) >= #{QueryValidator::MIN_GROUP_SIZE}")
      expect(res[:valid]).to eq(true)
    end

    it "accepts HAVING with > operator" do
      res = QueryValidator.validate("SELECT id, COUNT(*) FROM people GROUP BY id HAVING COUNT(*) > #{QueryValidator::MIN_GROUP_SIZE}")
      expect(res[:valid]).to eq(true)
    end

    it "accepts HAVING with boolean OR containing a valid condition" do
      sql = "SELECT id, COUNT(*) FROM people GROUP BY id HAVING (COUNT(*) >= #{QueryValidator::MIN_GROUP_SIZE} OR COUNT(*) >= 100)"
      res = QueryValidator.validate(sql)
      expect(res[:valid]).to eq(true)
    end

    it "rejects subqueries in SELECT" do
      res = QueryValidator.validate("SELECT (SELECT COUNT(*) FROM other) AS subcount FROM people")
      expect(res[:valid]).to eq(false)
      expect(res[:errors].join).to match(/Subqueries are not allowed/)
    end

    it "rejects subqueries in FROM" do
      res = QueryValidator.validate("SELECT * FROM (SELECT 1) AS sub")
      expect(res[:valid]).to eq(false)
      expect(res[:errors].join).to match(/Subqueries are not allowed/)
    end

    it "rejects subqueries in WHERE" do
      sql = <<~SQL
        SELECT id FROM people
        WHERE EXISTS (SELECT 1 FROM other WHERE other.x = people.x)
      SQL
      res = QueryValidator.validate(sql)
      expect(res[:valid]).to eq(false)
      expect(res[:errors].join).to match(/Subqueries are not allowed/)
    end

    it "rejects unsupported aggregate functions" do
      res = QueryValidator.validate("SELECT MEDIAN(age) FROM people")
      expect(res[:valid]).to eq(false)
      expect(res[:errors].join).to match(/Only these aggregates are allowed:/)
    end

    it "estimates epsilon: COUNT gives minimum epsilon (0.1)" do
      res = QueryValidator.validate("SELECT COUNT(*) FROM people")
      expect(res[:valid]).to eq(true)
      expect(res[:estimated_epsilon]).to be >= 0.1
    end

    it "estimates epsilon: AVG/SUM/STDDEV increase epsilon" do
      r1 = QueryValidator.validate("SELECT AVG(age) FROM people")
      r2 = QueryValidator.validate("SELECT SUM(cost) FROM people")
      r3 = QueryValidator.validate("SELECT STDDEV(x) FROM people")

      expect(r1[:valid]).to eq(true)
      expect(r2[:valid]).to eq(true)
      expect(r3[:valid]).to eq(true)

      expect(r1[:estimated_epsilon]).to be >= 0.5
      expect(r2[:estimated_epsilon]).to be >= 0.5
      expect(r3[:estimated_epsilon]).to be >= 0.5
    end

    it "handles the extract_select_statement nil branch via stubbing parse result" do
      fake = double(tree: double(stmts: []))
      allow(PgQuery).to receive(:parse).and_return(fake)
      res = QueryValidator.validate("SELECT 1 FROM t")
      expect(res[:valid]).to eq(false)
      expect(res[:errors]).to include("Query must be a SELECT statement")
    ensure
      # restore normal behavior for subsequent tests
      allow(PgQuery).to receive(:parse).and_call_original
    end
  end
end
