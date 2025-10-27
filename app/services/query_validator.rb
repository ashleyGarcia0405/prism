module QueryValidator
  ALLOWED_FUNCTIONS = %w[COUNT SUM AVG MIN MAX].freeze

  def self.validate(sql)
    ALLOWED_FUNCTIONS.any? { |f| sql.include?(f) }
  end
end