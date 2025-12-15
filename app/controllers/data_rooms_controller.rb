# frozen_string_literal: true

class DataRoomsController < ApplicationController
  skip_before_action :authenticate_web_user!, only: [ :show_invitation, :accept_invitation, :decline_invitation ]
  skip_before_action :ensure_api_auth_token, only: [ :show_invitation, :accept_invitation, :decline_invitation ]
  def index
    @data_rooms = fetch_data_rooms
  end

  def show
    @data_room = fetch_data_room(params[:id])
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
    response = make_api_request(
      :post,
      "/api/v1/data_rooms",
      { data_room: data_room_params }
    )

    if response[:success]
      redirect_to data_room_path(response[:data]["id"]),
                  notice: "Data room created successfully!"
    else
      @data_room = DataRoom.new(data_room_params)
      @datasets = current_user.organization.datasets.where.not(table_name: nil).order(:name)
      flash.now[:alert] = response[:errors]&.join(", ") || "Failed to create data room"
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
    make_api_request_with_token(method, path, body, session[:auth_token])
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
