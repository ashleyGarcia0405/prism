# frozen_string_literal: true

class DataRoomParticipant < ApplicationRecord
  belongs_to :data_room
  belongs_to :organization
  belongs_to :dataset

  validates :status, presence: true, inclusion: {
    in: %w[invited attested computed declined],
    message: "%{value} is not a valid status"
  }

  validates :organization_id, uniqueness: {
    scope: :data_room_id,
    message: "is already a participant in this data room"
  }

  # Status enum
  enum :status, {
    invited: "invited",
    attested: "attested",
    computed: "computed",
    declined: "declined"
  }, suffix: true

  # Attest to participate
  def attest!
    update!(status: "attested", attested_at: Time.current)
  end

  # Mark as computed
  def mark_computed!(metadata = {})
    update!(
      status: "computed",
      computed_at: Time.current,
      computation_metadata: metadata
    )
  end

  # Decline participation
  def decline!
    update!(status: "declined")
  end
end