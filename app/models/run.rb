class Run < ApplicationRecord
  belongs_to :query
  belongs_to :user

  # status transitions: pending -> running -> completed/failed
  enum :status, {
    pending: "pending",
    running: "running",
    completed: "completed",
    failed: "failed"
  }, default: "pending"

  validates :status, presence: true

  # helper methods: status checks
  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def running?
    status == "running"
  end

  def pending?
    status == "pending"
  end
end
