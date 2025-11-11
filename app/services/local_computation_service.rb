# frozen_string_literal: true

# LocalComputationService executes queries on a single organization's dataset
# This is the local computation step in multi-party computation
class LocalComputationService
  attr_reader :participant, :dataset, :query_params

  def initialize(participant)
    @participant = participant
    @dataset = participant.dataset
    @data_room = participant.data_room
    @query_params = @data_room.query_params || {}
  end

  # Execute local computation and return masked result
  #
  # @return [Hash] Contains share (masked result) and encrypted noise
  def compute
    start_time = Time.now

    # 1. Execute local query on dataset
    local_result = execute_local_query

    # 2. Generate random masking noise
    masking_noise = MPCEngine.generate_masking_noise(magnitude: local_result.abs * 2)

    # 3. Add noise to result (creates share)
    share = local_result + masking_noise

    # 4. Encrypt the noise for coordinator
    encrypted_noise = encrypt_noise(masking_noise)

    # 5. Store computation metadata
    @participant.update!(
      status: 'computed',
      computed_at: Time.current,
      computation_metadata: {
        share: share,
        encrypted_noise: encrypted_noise,
        execution_time_ms: ((Time.now - start_time) * 1000).to_i
      }
    )

    {
      share: share,
      encrypted_noise: encrypted_noise,
      participant_id: @participant.id,
      organization_id: @participant.organization_id
    }
  rescue StandardError => e
    # Mark participant as failed
    @participant.update!(
      status: 'failed',
      computation_metadata: {
        error: e.message,
        backtrace: e.backtrace.first(5)
      }
    )

    raise
  end

  private

  # Execute query on local dataset
  def execute_local_query
    # Use MPCQueryParser to build SQL
    parser = MPCQueryParser.new(@query_params.presence || { 'query_type' => @data_room.query_type })

    # Validate query can run on this dataset
    validation = parser.validate_for_dataset(@dataset)
    unless validation[:valid]
      raise "Query validation failed: #{validation[:errors].join(', ')}"
    end

    # Build and execute SQL
    sql = parser.build_sql_for_dataset(@dataset)
    result = ActiveRecord::Base.connection.execute(sql)

    # Extract result based on query type
    case parser.query_type
    when 'sum', 'avg'
      result.first['sum']&.to_f || 0.0
    when 'count'
      result.first['count']&.to_i || 0
    else
      raise "Unsupported query type: #{parser.query_type}"
    end
  end

  # Encrypt noise with coordinator's public key
  def encrypt_noise(noise)
    public_key = load_coordinator_public_key

    # Convert noise to string and encrypt
    encrypted_bytes = public_key.public_encrypt(noise.to_s)

    # Encode as base64 for storage
    Base64.strict_encode64(encrypted_bytes)
  rescue StandardError => e
    Rails.logger.error("Failed to encrypt noise: #{e.message}")
    raise "Encryption failed: #{e.message}"
  end

  # Load coordinator's public key
  def load_coordinator_public_key
    # Try to load from environment variable first
    if ENV['MPC_COORDINATOR_PUBLIC_KEY'].present?
      OpenSSL::PKey::RSA.new(ENV['MPC_COORDINATOR_PUBLIC_KEY'])
    else
      # Fallback: Load from Rails credentials
      key_string = Rails.application.credentials.dig(:mpc, :coordinator_public_key)
      raise "MPC coordinator public key not configured" unless key_string

      OpenSSL::PKey::RSA.new(key_string)
    end
  end
end