# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataRoomParticipant, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:data_room) }
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:dataset) }
  end

  describe "validations" do
    subject { build(:data_room_participant) }

    it { is_expected.to validate_presence_of(:status) }

    it "validates status inclusion" do
      participant = build(:data_room_participant)
      expect {
        participant.update(status: "invalid")
      }.to raise_error(ArgumentError, /'invalid' is not a valid status/)
    end

    it "validates uniqueness of organization_id scoped to data_room_id" do
      data_room = create(:data_room)
      organization = create(:organization)
      create(:data_room_participant, data_room: data_room, organization: organization)

      duplicate = build(:data_room_participant, data_room: data_room, organization: organization)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:organization_id]).to include("is already a participant in this data room")
    end
  end

  describe "status transitions" do
    let(:participant) { create(:data_room_participant) }

    it "has invited status by default" do
      expect(participant.status).to eq("invited")
    end

    it "can transition to attested" do
      participant.update!(status: "attested")
      expect(participant.status).to eq("attested")
    end

    it "can transition to computed" do
      participant.update!(status: "computed")
      expect(participant.status).to eq("computed")
    end

    it "can transition to declined" do
      participant.update!(status: "declined")
      expect(participant.status).to eq("declined")
    end
  end

  describe "#attest!" do
    let(:participant) { create(:data_room_participant, status: "invited") }

    it "updates status to attested" do
      participant.attest!
      expect(participant.status).to eq("attested")
    end

    it "sets attested_at timestamp" do
      participant.attest!
      expect(participant.attested_at).to be_within(1.second).of(Time.current)
    end
  end

  describe "#mark_computed!" do
    let(:participant) { create(:data_room_participant, :attested) }
    let(:metadata) { { result: "encrypted", shares: [ 1, 2, 3 ] } }

    it "updates status to computed" do
      participant.mark_computed!(metadata)
      expect(participant.status).to eq("computed")
    end

    it "sets computed_at timestamp" do
      participant.mark_computed!(metadata)
      expect(participant.computed_at).to be_within(1.second).of(Time.current)
    end

    it "stores computation metadata" do
      participant.mark_computed!(metadata)
      expect(participant.computation_metadata).to eq(metadata.stringify_keys)
    end
  end

  describe "#decline!" do
    let(:participant) { create(:data_room_participant, status: "invited") }

    it "updates status to declined" do
      participant.decline!
      expect(participant.status).to eq("declined")
    end
  end
end