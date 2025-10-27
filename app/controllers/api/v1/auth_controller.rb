# frozen_string_literal: true

module Api
  module V1
    class AuthController < Api::BaseController
      skip_before_action :authenticate_user!, only: [:login, :register]

      def register
        user = User.new(user_params)

        if user.save
          token = JsonWebToken.encode(user_id: user.id)
          render json: {
            token: token,
            user: {
              id: user.id,
              name: user.name,
              email: user.email,
              organization_id: user.organization_id
            }
          }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def login
        user = User.find_by(email: params[:email])

        if user&.authenticate(params[:password])
          token = JsonWebToken.encode(user_id: user.id)
          render json: {
            token: token,
            user: {
              id: user.id,
              name: user.name,
              email: user.email,
              organization_id: user.organization_id
            }
          }, status: :ok
        else
          render json: { error: 'Invalid email or password' }, status: :unauthorized
        end
      end

      private

      def user_params
        params.require(:user).permit(:name, :email, :password, :password_confirmation, :organization_id)
      end
    end
  end
end
