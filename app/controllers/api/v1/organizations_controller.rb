# frozen_string_literal: true

module Api
  module V1
    class OrganizationsController < Api::BaseController
      def show
        organization = Organization.find(params[:id])
        render json: {
          id: organization.id,
          name: organization.name,
          created_at: organization.created_at
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Organization not found' }, status: :not_found
      end

      def create
        organization = Organization.new(organization_params)

        if organization.save
          render json: {
            id: organization.id,
            name: organization.name,
            created_at: organization.created_at
          }, status: :created
        else
          render json: { errors: organization.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def organization_params
        params.require(:organization).permit(:name)
      end
    end
  end
end
