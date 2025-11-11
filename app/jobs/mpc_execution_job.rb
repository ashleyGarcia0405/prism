# frozen_string_literal: true

# MPCExecutionJob executes multi-party computation asynchronously
class MPCExecutionJob < ApplicationJob
  queue_as :default

  # Retry up to 2 times on failure
  retry_on StandardError, wait: 30.seconds, attempts: 2

  def perform(data_room_id)
    data_room = DataRoom.find(data_room_id)

    Rails.logger.info("Starting MPC execution for data room #{data_room.id}")

    # Execute MPC computation
    coordinator = MPCCoordinator.new(data_room)
    result = coordinator.execute

    if result[:success]
      Rails.logger.info("MPC execution completed for data room #{data_room.id}: #{result[:result]}")
    else
      Rails.logger.error("MPC execution failed for data room #{data_room.id}: #{result[:error]}")
    end

    result
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("DataRoom #{data_room_id} not found: #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("MPC execution job failed for data room #{data_room_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    # Update data room status
    DataRoom.find(data_room_id).update!(
      status: 'failed',
      result: {
        error: e.message,
        failed_at: Time.current
      }
    )

    raise
  end
end