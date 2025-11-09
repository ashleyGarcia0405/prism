# frozen_string_literal: true

module JwtHelpers
  def jwt_for(user, exp: 24.hours.from_now)
    payload = { user_id: user.id, exp: exp.to_i }
    JWT.encode(payload, ENV['JWT_SECRET'] || Rails.application.secret_key_base, 'HS256')
  end

  def auth_headers_for(user)
    { 'Authorization' => "Bearer #{jwt_for(user)}" }
  end
end

RSpec.configure do |config|
  config.include JwtHelpers
end
