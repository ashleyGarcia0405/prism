# lib/json_web_token.rb
require 'jwt'

class JsonWebToken
  ALGO = 'HS256'.freeze

  def self.secret
    ENV['JWT_SECRET'].presence || Rails.application.secret_key_base
  end

  # Works with:
  #   JsonWebToken.encode(user_id: 1)
  #   JsonWebToken.encode({ user_id: 1 })
  def self.encode(payload = {}, exp: 24.hours.from_now, **kw)
    data = payload.is_a?(Hash) ? payload.dup : {}
    data.merge!(kw) unless kw.empty?
    data[:exp] = exp.to_i
    JWT.encode(data, secret, ALGO)
  end

  # Returns decoded payload hash
  def self.decode(token)
    decoded, = JWT.decode(token, secret, true, { algorithm: ALGO })
    # convert "user_id" to :user_id etc., so test steps using symbol keys work
    decoded.transform_keys! { |k| k.to_sym rescue k }
    decoded
  end

end
