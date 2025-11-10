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
              mechanism: result[:mechanism]
            }
          )

          render json: {
            id: data_room.id,
            status: data_room.status,
            result: data_room.result,
            executed_at: data_room.executed_at,
            mechanism: result[:mechanism],
            proof_artifacts: result[:proof_artifacts]
          }, status: :ok
        rescue StandardError => e
          data_room.update!(status: "failed")

          AuditLogger.log(
            user: current_user,
            action: "data_room_execution_failed",
            target: data_room,
            metadata: { error: e.message }
          )

          render json: { error: "Execution failed: #{e.message}" }, status: :internal_server_error
        end
      end

      private

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
    end
  end
end
