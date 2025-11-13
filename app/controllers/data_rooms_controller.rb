# frozen_string_literal: true

class DataRoomsController < ApplicationController
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
      redirect_to data_room_path(params[:id]),
                  notice: "Organization invited successfully!"
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

  def make_api_request(method, path, body = nil)
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

    # Add authentication token from session
    if session[:auth_token]
      request["Authorization"] = "Bearer #{session[:auth_token]}"
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
