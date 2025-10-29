class Dataset < ApplicationRecord
  belongs_to :organization
  has_one :privacy_budget, dependent: :destroy
  has_many :queries, dependent: :destroy

  validates :name, presence: true

  after_create :create_default_privacy_budget

  private

  def create_default_privacy_budget
    create_privacy_budget!(
      total_epsilon: 3.0,
      consumed_epsilon: 0.0,
      reserved_epsilon: 0.0
    )
  end
end
