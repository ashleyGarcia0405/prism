module Api
  module V1
    class AuditEventsController < Api::BaseController
      def index
        org_id = (params[:organization_id] || current_user.organization_id).to_i
        scope = AuditEvent.joins(:user).where(users: { organization_id: org_id })
        scope = scope.where(action: params[:event_action]) if params[:event_action].present?

        page = params[:page].to_i > 0 ? params[:page].to_i : 1
        size = params[:page_size].to_i > 0 ? params[:page_size].to_i : 50

        events = scope.order(created_at: :desc).limit(size).offset((page - 1) * size)

        render json: {
          organization_id: org_id,
          count: events.size,
          events: events.map { |e|
            {
              id: e.id, action: e.action, user_id: e.user_id,
              target_type: e.target_type, target_id: e.target_id,
              metadata: e.metadata, created_at: e.created_at
            }
          }
        }, status: :ok
      end
    end
  end
end
