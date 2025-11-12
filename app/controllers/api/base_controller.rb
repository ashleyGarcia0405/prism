# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    before_action :authenticate_user!

    attr_reader :current_user

    private

    def authenticate_user!
      header = request.headers["Authorization"]

      unless header
        render json: { error: "Authentication required" }, status: :unauthorized
        return
      end

      # validate Bearer token format (RFC 6750)
      unless header.start_with?("Bearer ")
        render json: { error: "Invalid authorization format. Expected 'Bearer <token>'" }, status: :unauthorized
        return
      end

      # extract token (split into max 2 parts in case token contains spaces)
      token = header.split(" ", 2).last

      begin
        decoded = JsonWebToken.decode(token)
        @current_user = User.find(decoded[:user_id])
      rescue JWT::DecodeError => e
        render json: { error: e.message }, status: :unauthorized
      rescue ActiveRecord::RecordNotFound
        render json: { error: "User not found" }, status: :unauthorized
      end
    end

    def skip_authentication
      # override this in controllers that don't need authentication
    end
  end
end
