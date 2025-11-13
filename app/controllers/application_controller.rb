class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_test_session_if_needed
  before_action :authenticate_web_user!
  before_action :ensure_api_auth_token
  helper_method :current_user, :logged_in?

  private

  def set_test_session_if_needed
    # In test environment, allow setting session via test_user_id parameter
    if Rails.env.test? && params[:test_user_id].present?
      session[:user_id] = params[:test_user_id].to_i
    end
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def authenticate_web_user!
    if Rails.env.test? && params[:test_user_id].present?
      session[:user_id] = params[:test_user_id].to_i
    end

    unless logged_in?
      redirect_to login_path, alert: "Please log in to continue"
    end
  end

  def ensure_api_auth_token
    return unless logged_in?

    session[:auth_token] ||= JsonWebToken.encode(user_id: current_user.id)
  rescue StandardError => e
    Rails.logger.error("Failed to issue API auth token: #{e.message}")
  end
end
