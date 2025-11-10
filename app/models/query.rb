class Query < ApplicationRecord
  belongs_to :dataset
  belongs_to :user
  has_many :runs, dependent: :destroy

  validates :sql, presence: true
  validates :backend, presence: true, inclusion: {
    in: ->(_record) { BackendRegistry::BACKENDS.keys },
    message: ->(object, _data) { "#{object.backend} is not a valid backend" }
  }
  validate :backend_must_be_available
  validate :backend_must_support_operation

  before_validation :set_default_backend, on: :create
  before_validation :validate_sql_safety, on: :create
  before_validation :set_estimated_epsilon, on: :create

  private

  def set_default_backend
    self.backend ||= "dp_sandbox"
  end

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

  def backend_must_be_available
    return unless backend

    unless BackendRegistry.backend_available?(backend)
      backend_config = BackendRegistry.get_backend(backend)
      errors.add(:backend, "is not available. #{backend_config[:unavailable_reason]}. " \
                          "Available alternatives: #{backend_config[:alternatives]&.join(', ')}")
    end
  rescue BackendRegistry::BackendNotFoundError
    # Will be caught by inclusion validation
  end

  def backend_must_support_operation
    return unless backend && sql

    sql_lower = sql.downcase
    operation = if sql_lower.match?(/count\s*\(/i)
      "COUNT"
    elsif sql_lower.match?(/sum\s*\(/i)
      "SUM"
    elsif sql_lower.match?(/avg\s*\(/i)
      "AVG"
    elsif sql_lower.match?(/min\s*\(/i)
      "MIN"
    elsif sql_lower.match?(/max\s*\(/i)
      "MAX"
    else
      return # Unknown operation, will be caught by SQL validation
    end

    return unless BackendRegistry.backend_available?(backend)

    unless BackendRegistry.supports_operation?(backend, operation)
      backend_config = BackendRegistry.get_backend(backend)
      supported = backend_config[:features].join(", ")
      errors.add(:backend, "does not support #{operation}. Supported operations: #{supported}")
    end
  rescue BackendRegistry::BackendNotFoundError
    # Will be caught by inclusion validation
  end
end
