# frozen_string_literal: true

class PrivacyBudget < ApplicationRecord
  belongs_to :dataset

  validates :total_epsilon, presence: true, numericality: { greater_than: 0 }
  validates :consumed_epsilon, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reserved_epsilon, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :dataset_id, uniqueness: true

  validate :epsilon_values_within_total

  def remaining_epsilon
    total_epsilon - consumed_epsilon - reserved_epsilon
  end

  def can_reserve?(epsilon)
    remaining_epsilon >= epsilon
  end

  private

  def epsilon_values_within_total
    return unless total_epsilon && consumed_epsilon && reserved_epsilon

    if consumed_epsilon + reserved_epsilon > total_epsilon
      errors.add(:base, 'Consumed and reserved epsilon cannot exceed total epsilon')
    end
  end
end