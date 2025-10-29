require 'rails_helper'

RSpec.describe PrivacyBudgetService do
  let(:organization) { Organization.create!(name: "Test Hospital") }
  let(:dataset) { organization.datasets.create!(name: "Patient Data") }
  let(:budget) { dataset.privacy_budget }

  describe '.check_and_reserve' do
    context 'when budget is available' do
      it 'returns success' do
        result = PrivacyBudgetService.check_and_reserve(
          dataset: dataset,
          epsilon_needed: 0.5
        )

        expect(result[:success]).to be true
      end

      it 'reserves epsilon' do
        PrivacyBudgetService.check_and_reserve(
          dataset: dataset,
          epsilon_needed: 0.5
        )

        expect(budget.reload.reserved_epsilon).to eq(0.5)
      end

      it 'returns reservation_id' do
        result = PrivacyBudgetService.check_and_reserve(
          dataset: dataset,
          epsilon_needed: 0.5
        )

        expect(result[:reservation_id]).to be_present
      end

      it 'returns epsilon value' do
        result = PrivacyBudgetService.check_and_reserve(
          dataset: dataset,
          epsilon_needed: 0.5
        )

        expect(result[:epsilon]).to eq(0.5)
      end
    end

    context 'when budget is exhausted' do
      before do
        budget.update!(consumed_epsilon: 2.8)
      end

      it 'returns failure' do
        result = PrivacyBudgetService.check_and_reserve(
          dataset: dataset,
          epsilon_needed: 0.5
        )

        expect(result[:success]).to be false
      end

      it 'includes error message' do
        result = PrivacyBudgetService.check_and_reserve(
          dataset: dataset,
          epsilon_needed: 0.5
        )

        expect(result[:error]).to include('exceed privacy budget')
      end

      it 'does not reserve epsilon' do
        original_reserved = budget.reserved_epsilon

        PrivacyBudgetService.check_and_reserve(
          dataset: dataset,
          epsilon_needed: 0.5
        )

        expect(budget.reload.reserved_epsilon).to eq(original_reserved)
      end
    end

    context 'when budget exactly at limit' do
      before do
        budget.update!(consumed_epsilon: 2.5)
      end

      it 'allows reservation' do
        result = PrivacyBudgetService.check_and_reserve(
          dataset: dataset,
          epsilon_needed: 0.5
        )

        expect(result[:success]).to be true
      end
    end
  end

  describe '.commit' do
    let(:reservation_id) { SecureRandom.uuid }

    before do
      budget.update!(reserved_epsilon: 0.5)
    end

    it 'moves epsilon from reserved to consumed' do
      PrivacyBudgetService.commit(
        dataset: dataset,
        reservation_id: reservation_id,
        actual_epsilon: 0.5
      )

      budget.reload
      expect(budget.consumed_epsilon).to eq(0.5)
      expect(budget.reserved_epsilon).to eq(0.0)
    end

    it 'handles partial consumption' do
      PrivacyBudgetService.commit(
        dataset: dataset,
        reservation_id: reservation_id,
        actual_epsilon: 0.3
      )

      budget.reload
      expect(budget.consumed_epsilon).to eq(0.3)
      expect(budget.reserved_epsilon).to eq(0.2)
    end

    it 'adds to existing consumed epsilon' do
      budget.update!(consumed_epsilon: 1.0)

      PrivacyBudgetService.commit(
        dataset: dataset,
        reservation_id: reservation_id,
        actual_epsilon: 0.5
      )

      expect(budget.reload.consumed_epsilon).to eq(1.5)
    end
  end

  describe '.rollback' do
    let(:reservation_id) { SecureRandom.uuid }

    before do
      budget.update!(reserved_epsilon: 0.5)
    end

    it 'releases reserved epsilon' do
      PrivacyBudgetService.rollback(
        dataset: dataset,
        reservation_id: reservation_id,
        reserved_epsilon: 0.5
      )

      expect(budget.reload.reserved_epsilon).to eq(0.0)
    end

    it 'does not affect consumed epsilon' do
      budget.update!(consumed_epsilon: 1.0)

      PrivacyBudgetService.rollback(
        dataset: dataset,
        reservation_id: reservation_id,
        reserved_epsilon: 0.5
      )

      expect(budget.reload.consumed_epsilon).to eq(1.0)
    end

    it 'handles partial rollback' do
      PrivacyBudgetService.rollback(
        dataset: dataset,
        reservation_id: reservation_id,
        reserved_epsilon: 0.3
      )

      expect(budget.reload.reserved_epsilon).to eq(0.2)
    end
  end
end