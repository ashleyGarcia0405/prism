class Query < ApplicationRecord
  belongs_to :dataset
  belongs_to :user
  has_many :runs, dependent: :destroy

  validates :sql, presence: true

  before_validation :validate_sql_safety, on: :create
  before_validation :set_estimated_epsilon, on: :create

  private

  def validate_sql_safety
    return unless sql

    validation = QueryValidator.validate(sql)

    unless validation[:valid]
      validation[:errors].each { |error| errors.add(:sql, error) }
    end
  end

  def set_estimated_epsilon
    return unless sql

    validation = QueryValidator.validate(sql)
    self.estimated_epsilon ||= validation[:estimated_epsilon] if validation[:valid]
  end
end
