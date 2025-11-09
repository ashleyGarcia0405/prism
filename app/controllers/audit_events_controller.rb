# frozen_string_literal: true

class AuditEventsController < ApplicationController
  def index
    @audit_events = AuditEvent.joins(:user)
                               .where(users: { organization_id: current_user.organization_id })
                               .order(created_at: :desc)
                               .limit(50)
  end
end
