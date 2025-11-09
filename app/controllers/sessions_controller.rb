# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :authenticate_web_user!, only: [ :new, :create, :new_register, :create_register ]
  layout "application"

  def new
    # Login form
    redirect_to dashboard_path if logged_in?
  end

  def create
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to dashboard_path, notice: "Welcome back, #{user.name}!"
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def new_register
    # Registration form
    redirect_to dashboard_path if logged_in?
  end

  def create_register
    # Create organization first
    organization = Organization.new(organization_params)

    if organization.save
      # Create user under the organization
      user = organization.users.new(user_params)

      if user.save
        # Auto-login after successful registration
        session[:user_id] = user.id
        redirect_to dashboard_path, notice: "Welcome to Prism, #{user.name}! Your account has been created."
      else
        organization.destroy # Rollback organization if user creation fails
        flash.now[:alert] = user.errors.full_messages.join(", ")
        render :new_register, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = organization.errors.full_messages.join(", ")
      render :new_register, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    @current_user = nil
    redirect_to login_path, notice: "You have been logged out"
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

  def organization_params
    params.require(:organization).permit(:name)
  end
end
