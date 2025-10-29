# app/services/audit_logger.rb
class AuditLogger
  class << self
    def log(user:, action:, target: nil, metadata: {})
      AuditEvent.create!(
        user:        user,
        action:      action,
        target_type: target&.class&.name,
        target_id:   target&.id,
        metadata:    metadata
      )
    end
  end
end
