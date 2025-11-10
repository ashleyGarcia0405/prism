# frozen_string_literal: true

class DataRoom < ApplicationRecord
  belongs_to :creator, class_name: "User"
  has_many :participants, class_name: "DataRoomParticipant", dependent: :destroy
  has_many :invitations, class_name: "DataRoomInvitation", dependent: :destroy
  has_many :organizations, through: :participants
  has_many :datasets, through: :participants

  validates :name, presence: true
  validates :query_text, presence: true
  validates :status, presence: true, inclusion: {
    in: %w[pending attested executing completed failed],
    message: "%{value} is not a valid status"
  }

  # Status enum
  enum :status, {
    pending: "pending",
    attested: "attested",
    executing: "executing",
    completed: "completed",
    failed: "failed"
  }, suffix: true

  # Check if all participants have attested
  def all_attested?
    participants.exists? && participants.all? { |p| p.status == "attested" }
  end

  # Check if data room is ready to execute
  def ready_to_execute?
    all_attested? && status == "attested"
  end

  # Get participant count
  def participant_count
    participants.count
  end

  # Get attested participant count
  def attested_count
    participants.where(status: "attested").count
  end
end