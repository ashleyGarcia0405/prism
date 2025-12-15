# frozen_string_literal: true

class DataRoomsController < ApplicationController
  skip_before_action :authenticate_web_user!, only: [ :show_invitation, :accept_invitation, :decline_invitation ]
  skip_before_action :ensure_api_auth_token, only: [ :show_invitation, :accept_invitation, :decline_invitation ]
  def index
    # Get data rooms where user is creator or their org is a participant
    created_ids = DataRoom.where(creator: current_user).pluck(:id)
    participant_ids = DataRoom.joins(:participants)
                             .where(data_room_participants: { organization_id: current_user.organization_id })
                             .pluck(:id)
    all_ids = (created_ids + participant_ids).uniq

    data_rooms = DataRoom.where(id: all_ids).includes(:creator, :participants).order(created_at: :desc)

    @data_rooms = data_rooms.map { |dr|
      {
        "id" => dr.id,
        "name" => dr.name,
        "description" => dr.description,
        "status" => dr.status,
        "query_type" => dr.query_type,
        "creator_id" => dr.creator_id,
        "creator_name" => dr.creator.name,
        "participant_count" => dr.participants.count,
        "created_at" => dr.created_at
      }
    }
  end

  def show
    data_room = DataRoom.includes(:creator, participants: [:organization, :dataset]).find(params[:id])

    @data_room = {
      "id" => data_room.id,
      "name" => data_room.name,
      "description" => data_room.description,
      "status" => data_room.status,
      "query_text" => data_room.query_text,
      "query_type" => data_room.query_type,
      "creator_id" => data_room.creator_id,
      "result" => data_room.result,
      "executed_at" => data_room.executed_at,
      "created_at" => data_room.created_at,
      "participants" => data_room.participants.map { |p|
        {
          "id" => p.id,
          "organization_id" => p.organization_id,
          "organization_name" => p.organization.name,
          "dataset_id" => p.dataset_id,
          "dataset_name" => p.dataset&.name,
          "status" => p.status,
          "attested_at" => p.attested_at,
          "computed_at" => p.computed_at
        }
      }
    }

    @my_organization_id = current_user.organization_id
    @is_creator = @data_room["creator_id"] == current_user.id
    @my_participant = @data_room["participants"]&.find { |p| p["organization_id"] == @my_organization_id }
    @all_organizations = Organization.where.not(id: current_user.organization_id).order(:name)
  end

  def new
    @data_room = DataRoom.new
    @datasets = current_user.organization.datasets.where.not(table_name: nil).order(:name)
  end

  def create
    @data_room = DataRoom.new(data_room_params.merge(creator: current_user, status: "pending"))

    if @data_room.save
      AuditLogger.log(
        user: current_user,
        action: "data_room_created",
        target: @data_room,
        metadata: {
          name: @data_room.name,
          query_type: @data_room.query_type
        }
      )

      redirect_to data_room_path(@data_room.id),
                  notice: "Data room created successfully!"
    else
      @datasets = current_user.organization.datasets.where.not(table_name: nil).order(:name)
      flash.now[:alert] = @data_room.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  def invite
    response = make_api_request(
      :post,
      "/api/v1/data_rooms/#{params[:id]}/invite",
      { organization_id: params[:organization_id] }
    )

    if response[:success]
      # Send invitation email
      invitation = DataRoomInvitation.find(response[:data]["id"])
      DataRoomMailer.invitation_email(invitation).deliver_later

      redirect_to data_room_path(params[:id]),
                  notice: "Organization invited successfully! Invitation email sent."
    else
      redirect_to data_room_path(params[:id]),
                  alert: response[:error] || "Failed to invite organization"
    end
  end

  def attest
    response = make_api_request(
      :post,
      "/api/v1/data_rooms/#{params[:id]}/attest",
      { dataset_id: params[:dataset_id] }
    )

    if response[:success]
      redirect_to data_room_path(params[:id]),
                  notice: "Successfully attested with your dataset!"
    else
      redirect_to data_room_path(params[:id]),
                  alert: response[:error] || "Failed to attest"
    end
  end

  def execute
    response = make_api_request(
      :post,
      "/api/v1/data_rooms/#{params[:id]}/execute",
      { backend: params[:backend] || "mpc_mock" }
    )

    if response[:success]
      redirect_to data_room_path(params[:id]),
                  notice: "MPC computation initiated successfully!"
    else
      redirect_to data_room_path(params[:id]),
                  alert: response[:error] || "Failed to execute"
    end
  end

  # GET /data_rooms/invitations/:token/accept
  def show_invitation
    @invitation = find_invitation_by_token(params[:token])

    if @invitation.nil?
      render :invitation_not_found, status: :not_found
      return
    end

    if @invitation.expired?
      render :invitation_expired, status: :gone
      return
    end

    if @invitation.status != "pending"
      render :invitation_already_processed, status: :unprocessable_entity
      return
    end

    @data_room = @invitation.data_room
    @invited_by = @invitation.invited_by
    @organization = @invitation.organization

    # Check if user is logged in and from the right org
    if logged_in?
      if current_user.organization_id == @organization.id
        @datasets = @organization.datasets.where.not(table_name: nil).order(:name)
      else
        @wrong_organization = true
      end
    else
      @needs_login = true
    end
  end

  # POST /data_rooms/invitations/:token/accept
  def accept_invitation
    invitation = find_invitation_by_token(params[:token])

    if invitation.nil?
      redirect_to accept_data_room_invitation_path(params[:token]),
                  alert: "Invalid invitation token"
      return
    end

    unless logged_in?
      session[:invitation_token] = params[:token]
      session[:invitation_dataset_id] = params[:dataset_id]
      redirect_to login_path, alert: "Please log in to accept this invitation"
      return
    end

    unless current_user.organization_id == invitation.organization_id
      redirect_to accept_data_room_invitation_path(params[:token]),
                  alert: "This invitation is not for your organization"
      return
    end

    # Call API to accept invitation
    response = make_api_request_with_token(
      :post,
      "/api/v1/data_rooms/#{invitation.data_room_id}/accept_invitation",
      {
        invitation_token: params[:token],
        dataset_id: params[:dataset_id]
      },
      session[:auth_token]
    )

    if response[:success]
      redirect_to data_room_path(invitation.data_room_id),
                  notice: "Invitation accepted! You can now attest to participate in this data room."
    else
      redirect_to accept_data_room_invitation_path(params[:token]),
                  alert: response[:error] || "Failed to accept invitation"
    end
  end

  # POST /data_rooms/invitations/:token/decline
  def decline_invitation
    invitation = find_invitation_by_token(params[:token])

    if invitation.nil?
      redirect_to root_path, alert: "Invalid invitation token"
      return
    end

    invitation.decline!

    render :invitation_declined
  end

  private

  def data_room_params
    params.require(:data_room).permit(:name, :description, :query_text, :query_type, query_params: {})
  end

  def fetch_data_rooms
    response = make_api_request(:get, "/api/v1/data_rooms")
    response[:success] ? response[:data] : []
  end

  def fetch_data_room(id)
    response = make_api_request(:get, "/api/v1/data_rooms/#{id}")
    response[:success] ? response[:data] : nil
  end

  def find_invitation_by_token(token)
    DataRoomInvitation.find_by(invitation_token: token)
  end

  def make_api_request(method, path, body = nil)
    token = session[:auth_token]
    Rails.logger.debug("=== API Request Debug ===")
    Rails.logger.debug("Session auth_token present: #{token.present?}")
    Rails.logger.debug("Token value: #{token&.first(20)}...")
    make_api_request_with_token(method, path, body, token)
  end

  def make_api_request_with_token(method, path, body, token)
    require "net/http"
    require "uri"

    uri = URI("http://localhost:3000#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    request = case method
    when :get
                Net::HTTP::Get.new(uri)
    when :post
                Net::HTTP::Post.new(uri)
    when :patch
                Net::HTTP::Patch.new(uri)
    when :delete
                Net::HTTP::Delete.new(uri)
    end

    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"

    # Add authentication token
    if token
      request["Authorization"] = "Bearer #{token}"
    end

    request.body = body.to_json if body

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess) || response.code == "201" || response.code == "202"
      { success: true, data: JSON.parse(response.body) }
    else
      error_data = JSON.parse(response.body) rescue {}
      { success: false, error: error_data["error"], errors: error_data["errors"] }
    end
  rescue StandardError => e
    Rails.logger.error("API request failed: #{e.message}")
    { success: false, error: e.message }
  end
end
