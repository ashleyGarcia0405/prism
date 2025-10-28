class Query < ApplicationRecord
  belongs_to :dataset
  belongs_to :user
  has_many :runs, dependent: :destroy

  validates :sql, presence: true

  before_validation :set_estimated_epsilon, on: :create

  # simple epsilon estimation based on aggregate functions
  # MVP: COUNT/MIN/MAX = 0.1, AVG/SUM = 0.5
  def estimate_epsilon
    return 0.5 unless sql

    sql_upper = sql.upcase
    epsilon = 0.0

    # count occurrences of different aggregates
    epsilon += 0.1 * sql_upper.scan(/\bCOUNT\b/).length
    epsilon += 0.1 * sql_upper.scan(/\bMIN\b/).length
    epsilon += 0.1 * sql_upper.scan(/\bMAX\b/).length
    epsilon += 0.5 * sql_upper.scan(/\bAVG\b/).length
    epsilon += 0.5 * sql_upper.scan(/\bSUM\b/).length

    # minimum epsilon for any query
    [epsilon, 0.1].max
  end

  private

  def set_estimated_epsilon
    self.estimated_epsilon ||= estimate_epsilon
  end
end
