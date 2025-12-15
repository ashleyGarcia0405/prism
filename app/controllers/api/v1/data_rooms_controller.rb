# frozen_string_literal: true

require "ostruct"

module Api
  module V1
    class DataRoomsController < Api::BaseController
      # POST /api/v1/data_rooms
      def create
        data_room = DataRoom.new(data_room_params.merge(creator: current_user, status: "pending"))

        if data_room.save
          AuditLogger.log(
            user: current_user,
            action: "data_room_created",
            target: data_room,
            metadata: {
              name: data_room.name,
              query_type: data_room.query_type
            }
          )

          render json: {
            id: data_room.id,
            name: data_room.name,
            description: data_room.description,
            status: data_room.status,
            query_text: data_room.query_text,
            query_type: data_room.query_type,
            creator_id: data_room.creator_id,
            created_at: data_room.created_at
          }, status: :created
        else
          render json: { errors: data_room.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/data_rooms
      def index
        # Get data rooms where user is creator or their org is a participant
        created_ids = DataRoom.where(creator: current_user).pluck(:id)
        participant_ids = DataRoom.joins(:participants)
                                 .where(data_room_participants: { organization_id: current_user.organization_id })
                                 .pluck(:id)
        all_ids = (created_ids + participant_ids).uniq

        data_rooms = DataRoom.where(id: all_ids).order(created_at: :desc)

        render json: data_rooms.map { |dr|
          {
            id: dr.id,
            name: dr.name,
            description: dr.description,
            status: dr.status,
            query_type: dr.query_type,
            creator_id: dr.creator_id,
            participant_count: dr.participant_count,
            attested_count: dr.attested_count,
            created_at: dr.created_at
          }
        }, status: :ok
      end

      # GET /api/v1/data_rooms/:id
      def show
        data_room = find_data_room

        render json: {
          id: data_room.id,
          name: data_room.name,
          description: data_room.description,
          status: data_room.status,
          query_text: data_room.query_text,
          query_type: data_room.query_type,
          query_params: data_room.query_params,
          result: data_room.result,
          executed_at: data_room.executed_at,
          creator_id: data_room.creator_id,
          participant_count: data_room.participant_count,
          attested_count: data_room.attested_count,
          participants: data_room.participants.map { |p|
            {
              id: p.id,
              organization_id: p.organization_id,
              organization_name: p.organization.name,
              dataset_id: p.dataset_id,
              dataset_name: p.dataset.name,
              status: p.status,
              attested_at: p.attested_at
            }
          },
          created_at: data_room.created_at,
          updated_at: data_room.updated_at
        }, status: :ok
      end

      # POST /api/v1/data_rooms/:id/invite
      def invite
        data_room = find_data_room

        # Only creator can invite
        unless data_room.creator_id == current_user.id
          return render json: { error: "Only the creator can invite organizations" }, status: :forbidden
        end

        organization = Organization.find(params[:organization_id])

        # Check if already invited or participating
        if data_room.invitations.exists?(organization: organization)
          return render json: { error: "Organization already invited" }, status: :unprocessable_entity
        end

        if data_room.participants.exists?(organization: organization)
          return render json: { error: "Organization already participating" }, status: :unprocessable_entity
        end

        invitation = data_room.invitations.create!(
          organization: organization,
          invited_by: current_user
        )

        AuditLogger.log(
          user: current_user,
          action: "data_room_invitation_sent",
          target: data_room,
          metadata: {
            organization_id: organization.id,
            invitation_id: invitation.id
          }
        )

        render json: {
          id: invitation.id,
          data_room_id: data_room.id,
          organization_id: organization.id,
          status: invitation.status,
          invitation_token: invitation.invitation_token,
          expires_at: invitation.expires_at
        }, status: :created
      end

      # POST /api/v1/data_rooms/:id/accept_invitation
      def accept_invitation
        data_room = DataRoom.find(params[:id])
        invitation_token = params[:invitation_token]
        dataset_id = params[:dataset_id]

        unless invitation_token
          return render json: { error: "invitation_token is required" }, status: :bad_request
        end

        unless dataset_id
          return render json: { error: "dataset_id is required" }, status: :bad_request
        end

        # Find invitation by token
        invitation = data_room.invitations.find_by(invitation_token: invitation_token)

        unless invitation
          return render json: { error: "Invalid invitation token" }, status: :not_found
        end

        # Check if invitation is for current user's organization
        unless invitation.organization_id == current_user.organization_id
          return render json: { error: "This invitation is not for your organization" }, status: :forbidden
        end

        # Check if expired
        if invitation.expired?
          return render json: { error: "Invitation has expired" }, status: :unprocessable_entity
        end

        # Check if already accepted or declined
        if invitation.status != "pending"
          return render json: {
            error: "Invitation already #{invitation.status}",
            status: invitation.status
          }, status: :unprocessable_entity
        end

        # Verify dataset belongs to user's organization
        dataset = Dataset.find(dataset_id)
        unless dataset.organization_id == current_user.organization_id
          return render json: { error: "Dataset does not belong to your organization" }, status: :forbidden
        end

        # Accept the invitation (creates participant with status "invited")
        participant = invitation.accept!(dataset)

        AuditLogger.log(
          user: current_user,
          action: "data_room_invitation_accepted",
          target: data_room,
          metadata: {
            invitation_id: invitation.id,
            organization_id: invitation.organization_id,
            dataset_id: dataset.id,
            participant_id: participant.id
          }
        )

        render json: {
          id: participant.id,
          data_room_id: data_room.id,
          organization_id: participant.organization_id,
          dataset_id: participant.dataset_id,
          status: participant.status,
          invitation_status: invitation.status,
          message: "Invitation accepted successfully. You can now attest to participate."
        }, status: :ok
      end

      # POST /api/v1/data_rooms/:id/attest
      def attest
        data_room = find_data_room
        dataset_id = params[:dataset_id]

        unless dataset_id
          return render json: { error: "dataset_id is required" }, status: :bad_request
        end

        dataset = Dataset.find(dataset_id)

        # Check dataset belongs to user's organization
        unless dataset.organization_id == current_user.organization_id
          return render json: { error: "Dataset does not belong to your organization" }, status: :forbidden
        end

        # Find or create participant
        participant = data_room.participants.find_or_create_by!(
          organization_id: current_user.organization_id,
          dataset_id: dataset.id
        )

        # Attest
        participant.attest!

        # Check if all participants have attested
        if data_room.all_attested?
          data_room.update!(status: "attested")
        end

        AuditLogger.log(
          user: current_user,
          action: "data_room_attested",
          target: data_room,
          metadata: {
            participant_id: participant.id,
            dataset_id: dataset.id
          }
        )

        render json: {
          id: participant.id,
          data_room_id: data_room.id,
          organization_id: participant.organization_id,
          dataset_id: participant.dataset_id,
          status: participant.status,
          attested_at: participant.attested_at,
          data_room_status: data_room.status
        }, status: :ok
      end

      # POST /api/v1/data_rooms/:id/validate_query
      def validate_query
        data_room = find_data_room

        # Get all participant datasets
        datasets = data_room.participants.includes(:dataset, :organization).map(&:dataset)

        if datasets.empty?
          return render json: {
            valid: false,
            errors: [ "No participants in data room. Invite organizations first." ]
          }, status: :unprocessable_entity
        end

        # Parse query
        parser = MPCQueryParser.new(data_room.query_params)
        param_validation = parser.valid_query_params?

        unless param_validation[:valid]
          return render json: {
            valid: false,
            errors: param_validation[:errors]
          }, status: :unprocessable_entity
        end

        # Validate schema compatibility
        validator = SchemaValidator.new(datasets)
        column = parser.column_name

        # Perform comprehensive validation
        schema_validation = validator.validate_query_compatibility(column, parser.query_type)

        if schema_validation[:valid]
          render json: {
            valid: true,
            message: "Query is valid and ready to execute",
            warnings: schema_validation[:warnings],
            metadata: {
              datasets_count: datasets.count,
              column_name: column,
              column_type: datasets.first.column_type(column),
              query_type: parser.query_type,
              where_conditions: parser.where_conditions,
              common_columns: validator.common_columns.size,
              estimated_execution_time_ms: estimate_execution_time(datasets)
            }
          }, status: :ok
        else
          render json: {
            valid: false,
            errors: schema_validation[:errors],
            warnings: schema_validation[:warnings],
            suggestions: build_suggestions(validator, column, datasets)
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/data_rooms/:id/execute
      def execute
        data_room = find_data_room

        unless data_room.ready_to_execute?
          return render json: {
            error: "Data room not ready to execute",
            status: data_room.status,
            attested_count: data_room.attested_count,
            participant_count: data_room.participant_count
          }, status: :unprocessable_entity
        end

        # Check if MPC keys are configured
        unless MPCKeys.keys_configured?
          return render json: {
            error: "MPC coordinator keys not configured. Contact administrator.",
            details: "Run 'rake mpc:generate_keys' to configure MPC encryption."
          }, status: :service_unavailable
        end

        # Check backend preference
        backend = params[:backend] || "mpc_real"

        if backend == "mpc_mock"
          # Use mock executor for testing
          execute_with_mock(data_room)
        else
          # Use real MPC coordinator (async execution)
          execute_with_mpc(data_room)
        end
      end

      private

      # Execute with real MPC coordinator (async)
      def execute_with_mpc(data_room)
        # Update status to executing
        data_room.update!(status: "executing")

        # Enqueue background job for MPC execution
        MPCExecutionJob.perform_later(data_room.id)

        render json: {
          id: data_room.id,
          status: "executing",
          message: "MPC computation initiated. Poll this endpoint for results.",
          poll_url: api_v1_data_room_url(data_room)
        }, status: :accepted
      rescue StandardError => e
        data_room.update!(status: "failed")

        AuditLogger.log(
          user: current_user,
          action: "data_room_execution_failed",
          target: data_room,
          metadata: { error: e.message, backend: "mpc_real" }
        )

        render json: { error: "Failed to initiate MPC execution: #{e.message}" }, status: :internal_server_error
      end

      # Execute with mock MPC executor (synchronous, for testing)
      def execute_with_mock(data_room)
        # Update status to executing
        data_room.update!(status: "executing")

        # Create a mock query to pass to MockMpcExecutor
        mock_query = OpenStruct.new(
          sql: data_room.query_text,
          dataset: data_room.datasets.first, # For compatibility
          user: current_user
        )

        # Execute using MockMpcExecutor
        begin
          executor = MockMpcExecutor.new(mock_query)
          result = executor.execute

          data_room.update!(
            status: "completed",
            result: result[:data],
            executed_at: Time.current
          )

          # Mark all participants as computed
          data_room.participants.each do |participant|
            participant.mark_computed!(result[:proof_artifacts])
          end

          AuditLogger.log(
            user: current_user,
            action: "data_room_executed",
            target: data_room,
            metadata: {
              participant_count: data_room.participant_count,
              mechanism: result[:mechanism],
              backend: "mpc_mock"
            }
          )

          render json: {
            id: data_room.id,
            status: data_room.status,
            result: data_room.result,
            executed_at: data_room.executed_at,
            mechanism: result[:mechanism],
            proof_artifacts: result[:proof_artifacts],
            backend: "mpc_mock"
          }, status: :ok
        rescue StandardError => e
          data_room.update!(status: "failed")

          AuditLogger.log(
            user: current_user,
            action: "data_room_execution_failed",
            target: data_room,
            metadata: { error: e.message, backend: "mpc_mock" }
          )

          render json: { error: "Execution failed: #{e.message}" }, status: :internal_server_error
        end
      end

      def data_room_params
        params.require(:data_room).permit(:name, :description, :query_text, :query_type, query_params: {})
      end

      def find_data_room
        data_room = DataRoom.find(params[:id])

        # Check if user has access (creator, participant, or invited)
        unless data_room.creator_id == current_user.id ||
               data_room.participants.exists?(organization_id: current_user.organization_id) ||
               data_room.invitations.exists?(organization_id: current_user.organization_id)
          raise ActiveRecord::RecordNotFound
        end

        data_room
      end

      # Estimate execution time based on dataset sizes
      def estimate_execution_time(datasets)
        # Rough estimate: 100ms base + 50ms per dataset + 10ms per 1000 rows
        base_time = 100
        per_dataset = datasets.count * 50

        # For now, we gonna assume average dataset size
        # In production, query actual row counts
        estimated_rows = datasets.count * 1000
        row_time = (estimated_rows / 1000) * 10

        base_time + per_dataset + row_time
      end

      # Build helpful suggestions for query errors
      def build_suggestions(validator, column_name, datasets)
        suggestions = {}

        # Suggest alternative column names
        alternatives = validator.suggest_alternatives(column_name)
        if alternatives.any?
          suggestions[:alternative_columns] = alternatives
        end

        # Show common columns across all datasets
        common = validator.common_columns
        if common.any?
          suggestions[:common_columns] = common
          suggestions[:hint] = "These columns exist in all datasets: #{common.join(', ')}"
        end

        # Show schema for each dataset
        suggestions[:schemas] = datasets.map do |ds|
          {
            dataset_id: ds.id,
            organization: ds.organization.name,
            columns: ds.columns
          }
        end

        suggestions
      end
    end
  end
end
