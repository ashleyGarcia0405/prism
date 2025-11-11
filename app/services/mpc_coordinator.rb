# frozen_string_literal: true

# MPCCoordinator orchestrates multi-party computation across participants
# Coordinates local computations, collects shares, and reconstructs results
class MPCCoordinator
  attr_reader :data_room, :participants

  def initialize(data_room)
    @data_room = data_room
    @participants = data_room.data_room_participants.includes(:dataset, :organization)
  end

  # Execute MPC computation
  #
  # @return [Hash] Result with success status and computed value
  def execute
    start_time = Time.now

    # 1. Verify preconditions
    validation_result = validate_ready_for_execution
    return validation_result unless validation_result[:valid]

    # 2. Update data room status
    @data_room.update!(status: 'executing')

    # 3. Trigger local computation for each participant
    local_results = compute_local_results

    # 4. Collect shares from participants
    shares = local_results.map { |result| result[:share] }
    encrypted_noises = local_results.map { |result| result[:encrypted_noise] }

    # 5. Reconstruct result from shares
    noisy_sum = MPCEngine.reconstruct(shares)

    # 6. Decrypt and subtract noise to get true result
    total_noise = decrypt_and_sum_noise(encrypted_noises)
    true_result = noisy_sum - total_noise

    # 7. Add differential privacy noise (optional additional layer)
    epsilon = @data_room.epsilon || 0.1
    dp_result = MPCEngine.add_noise(true_result, epsilon: epsilon)

    # 8. Handle AVG query (need to divide by total count)
    final_result = compute_final_result(dp_result)

    execution_time_ms = ((Time.now - start_time) * 1000).to_i

    # 9. Store result in data room
    @data_room.update!(
      status: 'completed',
      result: {
        value: final_result,
        query_type: @data_room.query_type,
        participants_count: @participants.count,
        epsilon: epsilon,
        execution_time_ms: execution_time_ms,
        executed_at: Time.current
      },
      executed_at: Time.current
    )

    # 10. Log audit event
    log_mpc_execution(final_result, execution_time_ms)

    {
      success: true,
      result: final_result,
      data_room_id: @data_room.id,
      execution_time_ms: execution_time_ms
    }
  rescue StandardError => e
    # Mark as failed and log error
    @data_room.update!(
      status: 'failed',
      result: {
        error: e.message,
        failed_at: Time.current
      }
    )

    Rails.logger.error("MPC execution failed for data room #{@data_room.id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    {
      success: false,
      error: e.message,
      data_room_id: @data_room.id
    }
  end

  private

  # Validate data room is ready for execution
  def validate_ready_for_execution
    unless all_participants_attested?
      return {
        valid: false,
        error: 'Not all participants have attested to the query',
        missing_attestations: participants_pending_attestation.map(&:organization_id)
      }
    end

    unless participants.count >= 2
      return {
        valid: false,
        error: 'At least 2 participants required for MPC',
        participants_count: participants.count
      }
    end

    { valid: true }
  end

  # Check if all participants have attested
  def all_participants_attested?
    @participants.all? { |p| p.status == 'attested' }
  end

  # Get participants that haven't attested yet
  def participants_pending_attestation
    @participants.select { |p| p.status != 'attested' }
  end

  # Trigger local computation for all participants
  def compute_local_results
    results = []
    errors = []

    @participants.each do |participant|
      begin
        service = LocalComputationService.new(participant)
        result = service.compute
        results << result
      rescue StandardError => e
        errors << {
          participant_id: participant.id,
          organization_id: participant.organization_id,
          error: e.message
        }
      end
    end

    # If any participant failed, raise error
    if errors.any?
      raise "MPC computation failed for participants: #{errors.map { |e| e[:organization_id] }.join(', ')}"
    end

    results
  end

  # Decrypt noise values and sum them
  def decrypt_and_sum_noise(encrypted_noises)
    private_key = load_coordinator_private_key
    total_noise = 0.0

    encrypted_noises.each do |encrypted_noise|
      # Decode from base64
      encrypted_bytes = Base64.strict_decode64(encrypted_noise)

      # Decrypt with private key
      decrypted_string = private_key.private_decrypt(encrypted_bytes)

      # Convert back to number
      noise_value = decrypted_string.to_f
      total_noise += noise_value
    end

    total_noise
  rescue StandardError => e
    Rails.logger.error("Failed to decrypt noise: #{e.message}")
    raise "Failed to decrypt participant noise: #{e.message}"
  end

  # Compute final result based on query type
  def compute_final_result(raw_result)
    case @data_room.query_type
    when 'avg'
      # For AVG, we need to divide sum by count
      # Each participant computed local sum, so we have total sum
      # We need to get total count separately or store it
      # For simplicity, if count is stored in result metadata, use it
      total_count = compute_total_count
      return nil if total_count.zero?

      raw_result / total_count.to_f
    when 'sum', 'count'
      raw_result
    else
      raw_result
    end
  end

  # Compute total count across all participants (for AVG calculation)
  def compute_total_count
    # For AVG queries, we need COUNT from each participant
    # This is a simplified approach - in production, this would be
    # computed in parallel with the SUM
    total = 0

    @participants.each do |participant|
      dataset = participant.dataset
      query_params = @data_room.query_params || {}

      # Execute COUNT query
      where_clause = build_where_clause(query_params['where'])
      sql = "SELECT COUNT(*) as count FROM #{dataset.table_quoted}#{where_clause}"
      result = ActiveRecord::Base.connection.execute(sql)

      total += result.first['count'].to_i
    end

    total
  end

  # Build WHERE clause from conditions
  def build_where_clause(conditions)
    return '' unless conditions.is_a?(Hash) && conditions.any?

    condition_strings = conditions.map do |column, value|
      safe_column = ActiveRecord::Base.connection.quote_column_name(column)
      safe_value = ActiveRecord::Base.connection.quote(value)
      "#{safe_column} = #{safe_value}"
    end

    " WHERE #{condition_strings.join(' AND ')}"
  end

  # Load coordinator's private key
  def load_coordinator_private_key
    if ENV['MPC_COORDINATOR_PRIVATE_KEY'].present?
      OpenSSL::PKey::RSA.new(ENV['MPC_COORDINATOR_PRIVATE_KEY'])
    else
      key_string = Rails.application.credentials.dig(:mpc, :coordinator_private_key)
      raise "MPC coordinator private key not configured" unless key_string

      OpenSSL::PKey::RSA.new(key_string)
    end
  end

  # Log MPC execution to audit trail
  def log_mpc_execution(result, execution_time_ms)
    AuditLogger.log(
      user: @data_room.creator,
      action: 'mpc_executed',
      target: @data_room,
      metadata: {
        result: result,
        query_type: @data_room.query_type,
        participants_count: @participants.count,
        participant_organizations: @participants.map(&:organization_id),
        execution_time_ms: execution_time_ms,
        epsilon: @data_room.epsilon
      }
    )
  end
end