require 'rails_helper'

RSpec.describe PrivacyBudget, type: :model do
  describe 'associations' do
    it { should belong_to(:dataset) }
  end

  describe 'validations' do
    it { should validate_numericality_of(:total_epsilon).is_greater_than(0) }
    it { should validate_numericality_of(:consumed_epsilon).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:reserved_epsilon).is_greater_than_or_equal_to(0) }
  end

  describe '#remaining_epsilon' do
    it 'calculates remaining budget correctly' do
      budget = PrivacyBudget.new(
        total_epsilon: 3.0,
        consumed_epsilon: 1.5,
        reserved_epsilon: 0.5
      )

      expect(budget.remaining_epsilon).to eq(1.0)
    end

    it 'returns 0 when budget is exhausted' do
      budget = PrivacyBudget.new(
        total_epsilon: 3.0,
        consumed_epsilon: 2.0,
        reserved_epsilon: 1.0
      )

      expect(budget.remaining_epsilon).to eq(0.0)
    end
  end

  describe '#can_reserve?' do
    let(:budget) do
      PrivacyBudget.new(
        total_epsilon: 3.0,
        consumed_epsilon: 1.0,
        reserved_epsilon: 0.5
      )
    end

    it 'returns true when budget available' do
      expect(budget.can_reserve?(1.0)).to be true
    end

    it 'returns false when budget would be exceeded' do
      expect(budget.can_reserve?(2.0)).to be false
    end

    it 'returns true when exactly at limit' do
      expect(budget.can_reserve?(1.5)).to be true
    end
  end
end
