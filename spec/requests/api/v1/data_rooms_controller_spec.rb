# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::DataRoomsController", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:token) { JsonWebToken.encode(user_id: user.id) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "POST /api/v1/data_rooms" do
    let(:valid_params) do
      {
        data_room: {
          name: "Collaborative Analysis",
          description: "Multi-org data analysis",
          query_text: "SELECT COUNT(*) FROM data GROUP BY category HAVING COUNT(*) >= 25",
          query_type: "count"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new data room" do
        expect {
          post "/api/v1/data_rooms", params: valid_params, headers: headers
        }.to change(DataRoom, :count).by(1)
      end

      it "returns 201 status" do
        post "/api/v1/data_rooms", params: valid_params, headers: headers
        expect(response).to have_http_status(:created)
      end

      it "returns data room attributes" do
        post "/api/v1/data_rooms", params: valid_params, headers: headers
        json = JSON.parse(response.body)
        expect(json["name"]).to eq("Collaborative Analysis")
        expect(json["query_text"]).to be_present
        expect(json["status"]).to eq("pending")
        expect(json["creator_id"]).to eq(user.id)
      end

      it "logs audit event" do
        expect(AuditLogger).to receive(:log).with(
          user: user,
          action: "data_room_created",
          target: kind_of(DataRoom),
          metadata: hash_including(:name, :query_type)
        )
        post "/api/v1/data_rooms", params: valid_params, headers: headers
      end
    end

    context "with invalid parameters" do
      it "returns 422 status when name is missing" do
        invalid_params = valid_params.deep_dup
        invalid_params[:data_room][:name] = nil
        post "/api/v1/data_rooms", params: invalid_params, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error messages" do
        invalid_params = valid_params.deep_dup
        invalid_params[:data_room][:query_text] = nil
        post "/api/v1/data_rooms", params: invalid_params, headers: headers
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end
    end

    context "without authentication" do
      it "returns 401 status" do
        post "/api/v1/data_rooms", params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/data_rooms" do
    let!(:created_room) { create(:data_room, creator: user) }
    let!(:other_org_room) { create(:data_room) }
    let!(:participant_room) do
      room = create(:data_room)
      create(:data_room_participant, data_room: room, organization: organization)
      room
    end

    context "with authentication" do
      it "returns 200 status" do
        get "/api/v1/data_rooms", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "returns data rooms where user is creator" do
        get "/api/v1/data_rooms", headers: headers
        json = JSON.parse(response.body)
        ids = json.map { |dr| dr["id"] }
        expect(ids).to include(created_room.id)
      end

      it "returns data rooms where user's org is participant" do
        get "/api/v1/data_rooms", headers: headers
        json = JSON.parse(response.body)
        ids = json.map { |dr| dr["id"] }
        expect(ids).to include(participant_room.id)
      end

      it "does not return data rooms from other orgs" do
        get "/api/v1/data_rooms", headers: headers
        json = JSON.parse(response.body)
        ids = json.map { |dr| dr["id"] }
        expect(ids).not_to include(other_org_room.id)
      end

      it "returns data rooms with participant counts" do
        get "/api/v1/data_rooms", headers: headers
        json = JSON.parse(response.body)
        room_data = json.find { |dr| dr["id"] == participant_room.id }
        expect(room_data["participant_count"]).to eq(1)
      end
    end

    context "without authentication" do
      it "returns 401 status" do
        get "/api/v1/data_rooms"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/data_rooms/:id" do
    let(:data_room) { create(:data_room, creator: user) }
    let!(:participant) { create(:data_room_participant, :attested, data_room: data_room) }

    context "when user has access" do
      it "returns 200 status" do
        get "/api/v1/data_rooms/#{data_room.id}", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "returns data room details" do
        get "/api/v1/data_rooms/#{data_room.id}", headers: headers
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(data_room.id)
        expect(json["name"]).to eq(data_room.name)
        expect(json["query_text"]).to eq(data_room.query_text)
        expect(json["status"]).to eq(data_room.status)
      end

      it "includes participants information" do
        get "/api/v1/data_rooms/#{data_room.id}", headers: headers
        json = JSON.parse(response.body)
        expect(json["participants"]).to be_an(Array)
        expect(json["participants"].first["organization_name"]).to be_present
        expect(json["participants"].first["dataset_name"]).to be_present
      end
    end

    context "when user does not have access" do
      let(:other_room) { create(:data_room) }

      it "returns 404 status" do
        get "/api/v1/data_rooms/#{other_room.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/data_rooms/:id/invite" do
    let(:data_room) { create(:data_room, creator: user) }
    let(:target_organization) { create(:organization) }

    context "when user is creator" do
      it "creates an invitation" do
        expect {
          post "/api/v1/data_rooms/#{data_room.id}/invite",
               params: { organization_id: target_organization.id },
               headers: headers
        }.to change(DataRoomInvitation, :count).by(1)
      end

      it "returns 201 status" do
        post "/api/v1/data_rooms/#{data_room.id}/invite",
             params: { organization_id: target_organization.id },
             headers: headers
        expect(response).to have_http_status(:created)
      end

      it "returns invitation details" do
        post "/api/v1/data_rooms/#{data_room.id}/invite",
             params: { organization_id: target_organization.id },
             headers: headers
        json = JSON.parse(response.body)
        expect(json["invitation_token"]).to be_present
        expect(json["organization_id"]).to eq(target_organization.id)
        expect(json["expires_at"]).to be_present
      end

      it "logs audit event" do
        expect(AuditLogger).to receive(:log).with(
          user: user,
          action: "data_room_invitation_sent",
          target: data_room,
          metadata: hash_including(:organization_id, :invitation_id)
        )
        post "/api/v1/data_rooms/#{data_room.id}/invite",
             params: { organization_id: target_organization.id },
             headers: headers
      end
    end

    context "when organization is already invited" do
      before do
        create(:data_room_invitation, data_room: data_room, organization: target_organization)
      end

      it "returns 422 status" do
        post "/api/v1/data_rooms/#{data_room.id}/invite",
             params: { organization_id: target_organization.id },
             headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error message" do
        post "/api/v1/data_rooms/#{data_room.id}/invite",
             params: { organization_id: target_organization.id },
             headers: headers
        json = JSON.parse(response.body)
        expect(json["error"]).to include("already invited")
      end
    end

    context "when user is not creator" do
      let(:other_user) { create(:user) }
      let(:other_token) { JsonWebToken.encode(user_id: other_user.id) }
      let(:other_headers) { { "Authorization" => "Bearer #{other_token}" } }

      before do
        # Make other_user's organization a participant so they can access the room
        create(:data_room_participant, data_room: data_room, organization: other_user.organization)
      end

      it "returns 403 status" do
        post "/api/v1/data_rooms/#{data_room.id}/invite",
             params: { organization_id: target_organization.id },
             headers: other_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /api/v1/data_rooms/:id/attest" do
    let(:data_room) { create(:data_room) }
    let(:dataset) { create(:dataset, organization: organization) }

    before do
      # Create invitation for user's organization
      create(:data_room_invitation, data_room: data_room, organization: organization)
    end

    context "with valid dataset" do
      it "creates or updates participant" do
        expect {
          post "/api/v1/data_rooms/#{data_room.id}/attest",
               params: { dataset_id: dataset.id },
               headers: headers
        }.to change(DataRoomParticipant, :count).by(1)
      end

      it "returns 200 status" do
        post "/api/v1/data_rooms/#{data_room.id}/attest",
             params: { dataset_id: dataset.id },
             headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "sets participant status to attested" do
        post "/api/v1/data_rooms/#{data_room.id}/attest",
             params: { dataset_id: dataset.id },
             headers: headers
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("attested")
        expect(json["attested_at"]).to be_present
      end

      it "logs audit event" do
        expect(AuditLogger).to receive(:log).with(
          user: user,
          action: "data_room_attested",
          target: data_room,
          metadata: hash_including(:participant_id, :dataset_id)
        )
        post "/api/v1/data_rooms/#{data_room.id}/attest",
             params: { dataset_id: dataset.id },
             headers: headers
      end
    end

    context "when all participants attest" do
      before do
        # Create 2 participants, one already attested
        create(:data_room_participant, :attested, data_room: data_room)
      end

      it "updates data room status to attested" do
        post "/api/v1/data_rooms/#{data_room.id}/attest",
             params: { dataset_id: dataset.id },
             headers: headers
        json = JSON.parse(response.body)
        expect(json["data_room_status"]).to eq("attested")
      end
    end

    context "with dataset from another organization" do
      let(:other_dataset) { create(:dataset) }

      it "returns 403 status" do
        post "/api/v1/data_rooms/#{data_room.id}/attest",
             params: { dataset_id: other_dataset.id },
             headers: headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without dataset_id" do
      it "returns 400 status" do
        post "/api/v1/data_rooms/#{data_room.id}/attest", headers: headers
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "POST /api/v1/data_rooms/:id/execute" do
    let(:data_room) { create(:data_room, :attested) }
    let(:dataset1) { create(:dataset, organization: organization) }
    let(:dataset2) { create(:dataset) }

    before do
      create(:data_room_participant, :attested, data_room: data_room, organization: organization, dataset: dataset1)
      create(:data_room_participant, :attested, data_room: data_room, dataset: dataset2)
    end

    context "when data room is ready to execute" do
      it "returns 200 status" do
        post "/api/v1/data_rooms/#{data_room.id}/execute", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "updates status to completed" do
        post "/api/v1/data_rooms/#{data_room.id}/execute", headers: headers
        expect(data_room.reload.status).to eq("completed")
      end

      it "stores result" do
        post "/api/v1/data_rooms/#{data_room.id}/execute", headers: headers
        expect(data_room.reload.result).to be_present
      end

      it "returns result and proof artifacts" do
        post "/api/v1/data_rooms/#{data_room.id}/execute", headers: headers
        json = JSON.parse(response.body)
        expect(json["result"]).to be_present
        expect(json["mechanism"]).to eq("secret_sharing")
        expect(json["proof_artifacts"]).to be_present
      end

      it "marks all participants as computed" do
        post "/api/v1/data_rooms/#{data_room.id}/execute", headers: headers
        data_room.participants.each do |participant|
          expect(participant.reload.status).to eq("computed")
        end
      end

      it "logs audit event" do
        expect(AuditLogger).to receive(:log).with(
          user: user,
          action: "data_room_executed",
          target: data_room,
          metadata: hash_including(:participant_count, :mechanism)
        )
        post "/api/v1/data_rooms/#{data_room.id}/execute", headers: headers
      end
    end

    context "when data room is not ready to execute" do
      let(:pending_room) { create(:data_room) }

      before do
        create(:data_room_participant, data_room: pending_room, organization: organization, dataset: dataset1)
      end

      it "returns 422 status" do
        post "/api/v1/data_rooms/#{pending_room.id}/execute", headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error with status information" do
        post "/api/v1/data_rooms/#{pending_room.id}/execute", headers: headers
        json = JSON.parse(response.body)
        expect(json["error"]).to include("not ready")
        expect(json["status"]).to be_present
      end
    end
  end
end