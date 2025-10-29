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
end
