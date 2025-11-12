# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrivacyBudgetService, 'concurrency and race conditions' do
  let(:organization) { Organization.create!(name: "Test Hospital") }
  let(:dataset) { organization.datasets.create!(name: "Patient Data") }
  let!(:budget) { dataset.privacy_budget }

  describe 'concurrent reservations' do
    it 'handles multiple simultaneous reservation attempts' do
      threads = []
      results = []
      mutex = Mutex.new

      # Try to reserve budget from 5 threads simultaneously
      5.times do
        threads << Thread.new do
          result = PrivacyBudgetService.check_and_reserve(
            dataset: dataset,
            epsilon_needed: 1.0
          )
          mutex.synchronize { results << result }
        end
      end

      threads.each(&:join)

      # Should have some successes and some failures (budget only allows 3.0 total)
      successes = results.count { |r| r[:success] }
      failures = results.count { |r| !r[:success] }

      expect(successes).to be <= 3  # Can't exceed total budget
      expect(successes + failures).to eq(5)
    end

    it 'prevents budget over-allocation' do
      # Initial budget: 3.0
      # Reserve 2.0
      result1 = PrivacyBudgetService.check_and_reserve(
        dataset: dataset,
        epsilon_needed: 2.0
      )
      expect(result1[:success]).to be true

      # Try to reserve another 2.0 (should fail, only 1.0 left)
      result2 = PrivacyBudgetService.check_and_reserve(
        dataset: dataset,
        epsilon_needed: 2.0
      )
      expect(result2[:success]).to be false
      expect(result2[:error]).to include("Insufficient privacy budget")
    end

    it 'correctly updates remaining_epsilon' do
      initial_remaining = budget.reload.remaining_epsilon

      PrivacyBudgetService.check_and_reserve(
        dataset: dataset,
        epsilon_needed: 1.0
      )

      expect(budget.reload.remaining_epsilon).to eq(initial_remaining - 1.0)
    end
  end

  describe 'reservation and commit workflow' do
    it 'reserves then commits successfully' do
      reservation = PrivacyBudgetService.check_and_reserve(
        dataset: dataset,
        epsilon_needed: 0.5
      )

      expect(reservation[:success]).to be true
      reservation_id = reservation[:reservation_id]

      # Commit the reservation
      commit_result = PrivacyBudgetService.commit(
        dataset: dataset,
        reservation_id: reservation_id,
        actual_epsilon: 0.5
      )

      expect(commit_result[:success]).to be true

      # Check consumed epsilon increased
      budget.reload
      expect(budget.consumed_epsilon).to eq(0.5)
    end

    it 'handles rollback correctly' do
      initial_reserved = budget.reload.reserved_epsilon

      reservation = PrivacyBudgetService.check_and_reserve(
        dataset: dataset,
        epsilon_needed: 1.0
      )

      expect(reservation[:success]).to be true
      expect(budget.reload.reserved_epsilon).to eq(initial_reserved + 1.0)

      # Rollback the reservation
      rollback_result = PrivacyBudgetService.rollback(
        dataset: dataset,
        reservation_id: reservation[:reservation_id],
        reserved_epsilon: 1.0
      )

      expect(rollback_result[:success]).to be true
      expect(budget.reload.reserved_epsilon).to eq(initial_reserved)
    end

    it 'handles commit with different actual epsilon' do
      reservation = PrivacyBudgetService.check_and_reserve(
        dataset: dataset,
        epsilon_needed: 1.0
      )

      # Commit with less than reserved (actual query used less epsilon)
      commit_result = PrivacyBudgetService.commit(
        dataset: dataset,
        reservation_id: reservation[:reservation_id],
        actual_epsilon: 0.5
      )

      expect(commit_result[:success]).to be true

      budget.reload
      expect(budget.consumed_epsilon).to eq(0.5)
      # Reserved should be reduced by actual amount
      expect(budget.reserved_epsilon).to be < 1.0
    end
  end

  describe 'edge cases and error conditions' do
    it 'handles exact budget match' do
      # Try to reserve exactly all available budget
      result = PrivacyBudgetService.check_and_reserve(
        dataset: dataset,
        epsilon_needed: budget.total_epsilon
      )

      expect(result[:success]).to be true
      expect(budget.reload.remaining_epsilon).to eq(0.0)
    end

    it 'handles very small epsilon values' do
      result = PrivacyBudgetService.check_and_reserve(
        dataset: dataset,
        epsilon_needed: 0.001
      )

      expect(result[:success]).to be true
    end

    it 'prevents negative reserved_epsilon in rollback' do
      # Rollback without reservation should not go negative
      rollback_result = PrivacyBudgetService.rollback(
        dataset: dataset,
        reservation_id: SecureRandom.uuid,
        reserved_epsilon: 100.0
      )

      expect(rollback_result[:success]).to be true
      expect(budget.reload.reserved_epsilon).to eq(0.0)  # Should not go negative
    end

    it 'handles rollback of non-existent reservation gracefully' do
      result = PrivacyBudgetService.rollback(
        dataset: dataset,
        reservation_id: "non-existent-id",
        reserved_epsilon: 1.0
      )

      # Should succeed (idempotent operation)
      expect(result[:success]).to be true
    end

    it 'handles floating point precision issues' do
      # Reserve multiple small amounts that might have precision issues
      10.times do
        result = PrivacyBudgetService.check_and_reserve(
          dataset: dataset,
          epsilon_needed: 0.1
        )
        if result[:success]
          PrivacyBudgetService.commit(
            dataset: dataset,
            reservation_id: result[:reservation_id],
            actual_epsilon: 0.1
          )
        end
      end

      # Should handle precision correctly
      expect(budget.reload.consumed_epsilon).to be_between(0.0, budget.total_epsilon)
    end
  end

  describe 'budget exhaustion' do
    it 'rejects requests when budget exhausted' do
      # Consume all budget
      PrivacyBudgetService.check_and_reserve(
        dataset: dataset,
        epsilon_needed: 3.0
      )

      # Try to reserve more
      result = PrivacyBudgetService.check_and_reserve(
        dataset: dataset,
        epsilon_needed: 0.1
      )

      expect(result[:success]).to be false
      expect(result[:error]).to include("Insufficient privacy budget")
    end

    it 'provides budget status in error message' do
      # Consume most of budget
      PrivacyBudgetService.check_and_reserve(
        dataset: dataset,
        epsilon_needed: 2.9
      )

      # Try to reserve more than available
      result = PrivacyBudgetService.check_and_reserve(
        dataset: dataset,
        epsilon_needed: 0.5
      )

      expect(result[:success]).to be false
      expect(result[:error]).to include("Query would exceed privacy budget")
    end
  end

  describe 'database locking behavior' do
    it 'uses row-level locking to prevent races' do
      # This test verifies that with_lock is being used
      expect(budget).to receive(:with_lock).and_call_original

      PrivacyBudgetService.check_and_reserve(
        dataset: dataset,
        epsilon_needed: 0.5
      )
    end

    it 'handles database errors gracefully' do
      allow(budget).to receive(:with_lock).and_raise(ActiveRecord::LockWaitTimeout)

      expect {
        PrivacyBudgetService.check_and_reserve(
          dataset: dataset,
          epsilon_needed: 0.5
        )
      }.to raise_error(ActiveRecord::LockWaitTimeout)
    end
  end

  describe 'complex scenarios' do
    it 'handles multiple reserve-commit cycles' do
      5.times do |i|
        reservation = PrivacyBudgetService.check_and_reserve(
          dataset: dataset,
          epsilon_needed: 0.2
        )

        expect(reservation[:success]).to be true

        PrivacyBudgetService.commit(
          dataset: dataset,
          reservation_id: reservation[:reservation_id],
          actual_epsilon: 0.2
        )
      end

      expect(budget.reload.consumed_epsilon).to eq(1.0)
    end

    it 'handles mixed commit and rollback operations' do
      r1 = PrivacyBudgetService.check_and_reserve(dataset: dataset, epsilon_needed: 0.5)
      r2 = PrivacyBudgetService.check_and_reserve(dataset: dataset, epsilon_needed: 0.5)
      r3 = PrivacyBudgetService.check_and_reserve(dataset: dataset, epsilon_needed: 0.5)

      # Commit r1
      PrivacyBudgetService.commit(dataset: dataset, reservation_id: r1[:reservation_id], actual_epsilon: 0.5)

      # Rollback r2
      PrivacyBudgetService.rollback(dataset: dataset, reservation_id: r2[:reservation_id], reserved_epsilon: 0.5)

      # Commit r3
      PrivacyBudgetService.commit(dataset: dataset, reservation_id: r3[:reservation_id], actual_epsilon: 0.5)

      budget.reload
      expect(budget.consumed_epsilon).to eq(1.0)
      expect(budget.remaining_epsilon).to be > 0
    end
  end
end