# frozen_string_literal: true

class DataRoomInvitation < ApplicationRecord
  belongs_to :data_room
  belongs_to :organization
  belongs_to :invited_by, class_name: "User"

  validates :status, presence: true, inclusion: {
    in: %w[pending accepted declined expired],
    message: "%{value} is not a valid status"
  }
  validates :invitation_token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  # Status enum
  enum :status, {
    pending: "pending",
    accepted: "accepted",
    declined: "declined",
    expired: "expired"
  }, suffix: true

  # Check if invitation is expired
  def expired?
    expires_at.present? && expires_at < Time.current
  end

  # Accept invitation and create participant
  def accept!(dataset)
    return false if expired?

    transaction do
      update!(status: "accepted")

      DataRoomParticipant.create!(
        data_room: data_room,
        organization: organization,
        dataset: dataset,
        status: "invited"
      )
    end

    true
  end

  # Decline invitation
  def decline!
    update!(status: "declined")
  end

  private

  def generate_token
    self.invitation_token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at ||= 7.days.from_now
  end
end