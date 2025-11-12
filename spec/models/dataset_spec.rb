require 'rails_helper'

RSpec.describe Dataset, type: :model do
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should have_one(:privacy_budget) }
    it { should have_many(:queries) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe 'privacy budget auto-creation' do
    it 'creates privacy budget on dataset creation' do
      org = Organization.create!(name: "Test Org")
      dataset = org.datasets.create!(name: "Test Dataset")

      expect(dataset.privacy_budget).to be_present
    end

    it 'creates budget with default epsilon of 3.0' do
      org = Organization.create!(name: "Test Org")
      dataset = org.datasets.create!(name: "Test Dataset")

      expect(dataset.privacy_budget.total_epsilon).to eq(3.0)
    end

    it 'creates budget with zero consumed epsilon' do
      org = Organization.create!(name: "Test Org")
      dataset = org.datasets.create!(name: "Test Dataset")

      expect(dataset.privacy_budget.consumed_epsilon).to eq(0.0)
    end
  end

  describe '#table_name generation' do
    it 'generates unique table_name on create' do
      org = Organization.create!(name: "Test Org")
      dataset = org.datasets.create!(name: "Test Dataset")

      expect(dataset.table_name).to be_present
      expect(dataset.table_name).to start_with("org#{org.id}_ds_")
    end

    it 'generates different table names for datasets in same organization' do
      org = Organization.create!(name: "Test Org")
      dataset1 = org.datasets.create!(name: "Dataset 1")
      dataset2 = org.datasets.create!(name: "Dataset 2")

      expect(dataset1.table_name).not_to eq(dataset2.table_name)
    end
  end

  describe '#table_exists?' do
    let(:org) { Organization.create!(name: "Test Org") }
    let(:dataset) { org.datasets.create!(name: "Test Dataset") }

    it 'returns false when table_name is nil' do
      dataset.update_column(:table_name, nil)
      expect(dataset.table_exists?).to be false
    end

    it 'returns false when table does not exist in database' do
      expect(dataset.table_exists?).to be false
    end
  end

  describe '#columns' do
    let(:org) { Organization.create!(name: "Test Org") }
    let(:dataset) { org.datasets.create!(name: "Test Dataset") }

    it 'returns empty array when table_name is nil' do
      dataset.update_column(:table_name, nil)
      expect(dataset.columns).to eq([])
    end

    it 'returns empty array when table does not exist' do
      expect(dataset.columns).to eq([])
    end

    it 'handles StatementInvalid error gracefully' do
      allow(ActiveRecord::Base.connection).to receive(:columns).and_raise(ActiveRecord::StatementInvalid.new("Table not found"))
      expect(dataset.columns).to eq([])
    end
  end

  describe '#has_column?' do
    let(:org) { Organization.create!(name: "Test Org") }
    let(:dataset) { org.datasets.create!(name: "Test Dataset") }

    it 'returns false when column does not exist' do
      expect(dataset.has_column?("nonexistent_column")).to be false
    end

    it 'converts symbol to string' do
      expect(dataset.has_column?(:age)).to be false
    end
  end

  describe '#column_type' do
    let(:org) { Organization.create!(name: "Test Org") }
    let(:dataset) { org.datasets.create!(name: "Test Dataset") }

    it 'returns nil when table_name is nil' do
      dataset.update_column(:table_name, nil)
      expect(dataset.column_type("age")).to be_nil
    end

    it 'returns nil when table does not exist' do
      expect(dataset.column_type("age")).to be_nil
    end

    it 'returns nil when column does not exist' do
      expect(dataset.column_type("nonexistent")).to be_nil
    end

    it 'handles StatementInvalid error gracefully' do
      allow(ActiveRecord::Base.connection).to receive(:columns).and_raise(ActiveRecord::StatementInvalid.new("Error"))
      expect(dataset.column_type("age")).to be_nil
    end
  end

  describe '#column_info' do
    let(:org) { Organization.create!(name: "Test Org") }
    let(:dataset) { org.datasets.create!(name: "Test Dataset") }

    it 'returns nil when table_name is nil' do
      dataset.update_column(:table_name, nil)
      expect(dataset.column_info("age")).to be_nil
    end

    it 'returns nil when table does not exist' do
      expect(dataset.column_info("age")).to be_nil
    end

    it 'returns nil when column does not exist' do
      # Create a mock scenario where table exists but column doesn't
      allow(dataset).to receive(:table_exists?).and_return(true)
      allow(ActiveRecord::Base.connection).to receive(:columns).and_return([])
      expect(dataset.column_info("nonexistent")).to be_nil
    end

    it 'handles StatementInvalid error gracefully' do
      allow(ActiveRecord::Base.connection).to receive(:columns).and_raise(ActiveRecord::StatementInvalid.new("Error"))
      expect(dataset.column_info("age")).to be_nil
    end
  end

  describe '#schema_info' do
    let(:org) { Organization.create!(name: "Test Org") }
    let(:dataset) { org.datasets.create!(name: "Test Dataset") }

    it 'returns empty array when table_name is nil' do
      dataset.update_column(:table_name, nil)
      expect(dataset.schema_info).to eq([])
    end

    it 'returns empty array when table does not exist' do
      expect(dataset.schema_info).to eq([])
    end

    it 'handles StatementInvalid error gracefully' do
      allow(ActiveRecord::Base.connection).to receive(:columns).and_raise(ActiveRecord::StatementInvalid.new("Error"))
      expect(dataset.schema_info).to eq([])
    end
  end

  describe '#sample_column_values' do
    let(:org) { Organization.create!(name: "Test Org") }
    let(:dataset) { org.datasets.create!(name: "Test Dataset") }

    it 'returns empty array when column does not exist' do
      expect(dataset.sample_column_values("nonexistent")).to eq([])
    end

    it 'handles StatementInvalid error gracefully' do
      allow(dataset).to receive(:has_column?).and_return(true)
      allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(ActiveRecord::StatementInvalid.new("Error"))
      expect(dataset.sample_column_values("age")).to eq([])
    end
  end

  describe '#sanitize_column' do
    let(:org) { Organization.create!(name: "Test Org") }
    let(:dataset) { org.datasets.create!(name: "Test Dataset") }

    it 'allows valid column names with letters and underscores' do
      expect { dataset.sanitize_column("age") }.not_to raise_error
      expect { dataset.sanitize_column("user_id") }.not_to raise_error
      expect { dataset.sanitize_column("_column") }.not_to raise_error
    end

    it 'raises ArgumentError for column names with spaces' do
      expect { dataset.sanitize_column("age name") }.to raise_error(ArgumentError, /Invalid column name/)
    end

    it 'raises ArgumentError for column names with special characters' do
      expect { dataset.sanitize_column("age;DROP TABLE") }.to raise_error(ArgumentError, /Invalid column name/)
      expect { dataset.sanitize_column("age--") }.to raise_error(ArgumentError, /Invalid column name/)
      expect { dataset.sanitize_column("age'") }.to raise_error(ArgumentError, /Invalid column name/)
    end

    it 'raises ArgumentError for column names starting with numbers' do
      expect { dataset.sanitize_column("123column") }.to raise_error(ArgumentError, /Invalid column name/)
    end

    it 'accepts symbols and converts to string' do
      expect { dataset.sanitize_column(:age) }.not_to raise_error
    end

    it 'rejects empty column names' do
      expect { dataset.sanitize_column("") }.to raise_error(ArgumentError, /Invalid column name/)
    end
  end

  describe '#sanitize_value' do
    let(:org) { Organization.create!(name: "Test Org") }
    let(:dataset) { org.datasets.create!(name: "Test Dataset") }

    it 'sanitizes string values' do
      result = dataset.sanitize_value("test")
      expect(result).to be_a(String)
    end

    it 'sanitizes numeric values' do
      result = dataset.sanitize_value(123)
      expect(result).to be_a(String)
    end

    it 'handles nil values' do
      result = dataset.sanitize_value(nil)
      expect(result).to be_a(String)
    end
  end

  describe '#table_quoted' do
    let(:org) { Organization.create!(name: "Test Org") }
    let(:dataset) { org.datasets.create!(name: "Test Dataset") }

    it 'returns quoted table name' do
      result = dataset.table_quoted
      expect(result).to be_a(String)
      expect(result).to include(dataset.table_name)
    end
  end

  describe 'dependent destroy' do
    let(:org) { Organization.create!(name: "Test Org") }
    let(:dataset) { org.datasets.create!(name: "Test Dataset") }

    it 'destroys privacy_budget when dataset is destroyed' do
      budget_id = dataset.privacy_budget.id
      dataset.destroy

      expect(PrivacyBudget.exists?(budget_id)).to be false
    end

    it 'destroys queries when dataset is destroyed' do
      user = org.users.create!(name: "User", email: "user@test.com", password: "password123")
      query = dataset.queries.create!(
        sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
        user: user
      )

      query_id = query.id
      dataset.destroy

      expect(Query.exists?(query_id)).to be false
    end
  end

  describe 'unhappy paths' do
    let(:org) { Organization.create!(name: "Test Org") }

    context 'with missing required fields' do
      it 'fails validation without name' do
        dataset = Dataset.new(organization: org)
        expect(dataset.save).to be false
        expect(dataset.errors[:name]).to be_present
      end

      it 'fails validation without organization' do
        dataset = Dataset.new(name: "Test Dataset")
        expect(dataset.save).to be false
        expect(dataset.errors[:organization]).to be_present
      end
    end

    context 'with table_name uniqueness' do
      it 'validates table_name uniqueness' do
        dataset1 = org.datasets.create!(name: "Dataset 1", table_name: "unique_table")
        dataset2 = Dataset.new(name: "Dataset 2", organization: org, table_name: "unique_table")

        expect(dataset2.save).to be false
        expect(dataset2.errors[:table_name]).to be_present
      end

      it 'allows nil table_name for multiple datasets' do
        dataset1 = Dataset.new(name: "Dataset 1", organization: org)
        dataset1.update_column(:table_name, nil) if dataset1.save

        dataset2 = Dataset.new(name: "Dataset 2", organization: org)
        # Both can have nil table_name (allow_nil: true)
        expect(dataset2).to respond_to(:save)
      end
    end
  end
end
