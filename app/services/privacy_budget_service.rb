# frozen_string_literal: true

class PrivacyBudgetService
  class << self
    def check_and_reserve(dataset:, epsilon_needed:)
      if epsilon_needed.nil?
        return {
          success: false,
          error: "epsilon_needed is required"
        }
      end

      if epsilon_needed < 0
        return {
          success: false,
          error: "epsilon_needed must be a positive number, got: #{epsilon_needed}"
        }
      end

      budget = dataset.privacy_budget

      unless budget
        return {
          success: false,
          error: "Dataset does not have a privacy budget"
        }
      end

      # Lock the budget row to prevent race conditions
      budget.with_lock do
        unless budget.can_reserve?(epsilon_needed)
          return {
            success: false,
            error: "Query would exceed privacy budget. " \
                   "Consumed: #{budget.consumed_epsilon}, " \
                   "Reserved: #{budget.reserved_epsilon}, " \
                   "Available: #{budget.remaining_epsilon}, " \
                   "Requested: #{epsilon_needed}"
          }
        end

        # Reserve the epsilon
        budget.update!(reserved_epsilon: budget.reserved_epsilon + epsilon_needed)

        {
          success: true,
          reservation_id: SecureRandom.uuid,
          epsilon: epsilon_needed
        }
      end
    end

    def commit(dataset:, reservation_id:, actual_epsilon:)
      budget = dataset.privacy_budget

      unless budget
        return {
          success: false,
          error: "Dataset does not have a privacy budget"
        }
      end

      budget.with_lock do
        budget.update!(
          consumed_epsilon: budget.consumed_epsilon + actual_epsilon,
          reserved_epsilon: [ budget.reserved_epsilon - actual_epsilon, 0 ].max
        )
      end

      { success: true }
    end

    def rollback(dataset:, reservation_id:, reserved_epsilon:)
      budget = dataset.privacy_budget

      unless budget
        return {
          success: false,
          error: "Dataset does not have a privacy budget"
        }
      end

      budget.with_lock do
        budget.update!(
          reserved_epsilon: [ budget.reserved_epsilon - reserved_epsilon, 0 ].max
        )
      end

      { success: true }
    end
  end
end
