# spec/controllers/application_controller_spec.rb
require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      render plain: "ok"
    end
  end

  context "set_test_session_if_needed" do
    it "sets session when test_user_id param provided in test env" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("test"))
      get :index, params: { test_user_id: 123 }
      expect(session[:user_id]).to eq(123)
    end

    it "does not set session when not in test env" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      get :index, params: { test_user_id: 123 }
      expect(session[:user_id]).to be_nil
    end
  end

  context "authenticate_web_user!" do
    it "redirects to login when not logged in" do
      allow(controller).to receive(:logged_in?).and_return(false)
      get :index
      expect(response).to redirect_to(login_path)
    end

    it "allows when logged in" do
      allow(controller).to receive(:logged_in?).and_return(true)
      get :index
      expect(response).to have_http_status(:ok)
    end
  end
end
