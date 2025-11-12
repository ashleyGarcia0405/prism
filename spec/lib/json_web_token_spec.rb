# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JsonWebToken do
  let(:payload) { { user_id: 123, exp: 24.hours.from_now.to_i } }

  describe '.encode' do
    it 'encodes a payload into a JWT token' do
      token = JsonWebToken.encode(payload)
      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3)
    end

    it 'includes the payload data' do
      token = JsonWebToken.encode(payload)
      decoded = JWT.decode(token, Rails.application.credentials.secret_key_base, true, algorithm: 'HS256')
      expect(decoded[0]['user_id']).to eq(123)
    end

    it 'handles nil payload gracefully' do
      # JWT actually handles nil payload by encoding it
      token = JsonWebToken.encode(nil)
      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3)
    end

    it 'handles empty payload' do
      token = JsonWebToken.encode({})
      expect(token).to be_a(String)
    end
  end

  describe '.decode' do
    let(:valid_token) { JsonWebToken.encode(payload) }

    it 'decodes a valid token' do
      decoded = JsonWebToken.decode(valid_token)
      expect(decoded[:user_id]).to eq(123)
    end

    it 'returns symbolized keys' do
      decoded = JsonWebToken.decode(valid_token)
      expect(decoded.keys).to all(be_a(Symbol))
    end

    context 'with invalid tokens' do
      it 'raises DecodeError for malformed token' do
        expect {
          JsonWebToken.decode('invalid.token.here')
        }.to raise_error(JWT::DecodeError)
      end

      it 'raises DecodeError for empty token' do
        expect {
          JsonWebToken.decode('')
        }.to raise_error(JWT::DecodeError)
      end

      it 'raises DecodeError for nil token' do
        expect {
          JsonWebToken.decode(nil)
        }.to raise_error(JWT::DecodeError)
      end

      it 'raises DecodeError for token with wrong signature' do
        # Create token with different secret
        wrong_token = JWT.encode(payload, 'wrong_secret', 'HS256')
        expect {
          JsonWebToken.decode(wrong_token)
        }.to raise_error(JWT::VerificationError)
      end

      it 'raises ExpiredSignature for expired token' do
        expired_payload = { user_id: 123, exp: 1.hour.ago.to_i }
        expired_token = JWT.encode(expired_payload, Rails.application.credentials.secret_key_base, 'HS256')

        expect {
          JsonWebToken.decode(expired_token)
        }.to raise_error(JWT::ExpiredSignature)
      end

      it 'raises DecodeError for token with invalid algorithm' do
        # Create token with different algorithm
        none_token = JWT.encode(payload, nil, 'none')
        expect {
          JsonWebToken.decode(none_token)
        }.to raise_error(JWT::DecodeError)
      end

      it 'handles token missing required claims' do
        token_without_exp = JsonWebToken.encode({ user_id: 123 })
        decoded = JsonWebToken.decode(token_without_exp)
        expect(decoded[:user_id]).to eq(123)
      end
    end

    context 'with edge case payloads' do
      it 'handles very large user_id' do
        large_payload = { user_id: 999999999999, exp: 24.hours.from_now.to_i }
        token = JsonWebToken.encode(large_payload)
        decoded = JsonWebToken.decode(token)
        expect(decoded[:user_id]).to eq(999999999999)
      end

      it 'handles string user_id' do
        string_payload = { user_id: "123", exp: 24.hours.from_now.to_i }
        token = JsonWebToken.encode(string_payload)
        decoded = JsonWebToken.decode(token)
        expect(decoded[:user_id]).to eq("123")
      end

      it 'handles additional custom claims' do
        custom_payload = { user_id: 123, role: 'admin', permissions: ['read', 'write'], exp: 24.hours.from_now.to_i }
        token = JsonWebToken.encode(custom_payload)
        decoded = JsonWebToken.decode(token)
        expect(decoded[:role]).to eq('admin')
        expect(decoded[:permissions]).to eq(['read', 'write'])
      end
    end
  end
end