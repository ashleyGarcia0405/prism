# frozen_string_literal: true

require 'jwt'

class JsonWebToken
  # Secret key for JWT encoding/decoding
  # In production, use ENV['JWT_SECRET_KEY']
  SECRET_KEY = Rails.application.credentials.secret_key_base || ENV['JWT_SECRET_KEY']

  # Token expiration time (24 hours)
  EXPIRATION_TIME = 24.hours.from_now.to_i

  # Encode a payload into a JWT token
  # @param payload [Hash] The data to encode (e.g., { user_id: 1 })
  # @param exp [Integer] Optional expiration time (default: 24 hours)
  # @return [String] JWT token
  def self.encode(payload, exp = EXPIRATION_TIME)
    payload[:exp] = exp
    JWT.encode(payload, SECRET_KEY, 'HS256')
  end

  # Decode a JWT token
  # @param token [String] The JWT token to decode
  # @return [Hash] The decoded payload with symbolized keys
  # @raise [JWT::DecodeError] If token is invalid or expired
  def self.decode(token)
    body = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })[0]
    HashWithIndifferentAccess.new(body)
  rescue JWT::ExpiredSignature => e
    raise JWT::DecodeError, 'Token has expired'
  rescue JWT::DecodeError => e
    raise JWT::DecodeError, 'Invalid token'
  end
end