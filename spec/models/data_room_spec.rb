# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataRoom, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:creator).class_name("User") }
    it { is_expected.to have_many(:participants).class_name("DataRoomParticipant").dependent(:destroy) }
    it { is_expected.to have_many(:invitations).class_name("DataRoomInvitation").dependent(:destroy) }
    it { is_expected.to have_many(:organizations).through(:participants) }
    it { is_expected.to have_many(:datasets).through(:participants) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:query_text) }
    it { is_expected.to validate_presence_of(:status) }

    it "validates status inclusion" do
      data_room = build(:data_room)
      expect {
        data_room.update(status: "invalid")
      }.to raise_error(ArgumentError, /'invalid' is not a valid status/)
    end
  end

  describe "status transitions" do
    let(:data_room) { create(:data_room) }

    it "has pending status by default" do
      expect(data_room.status).to eq("pending")
    end

    it "can transition to attested" do
      data_room.update!(status: "attested")
      expect(data_room.status).to eq("attested")
    end

    it "can transition to executing" do
      data_room.update!(status: "executing")
      expect(data_room.status).to eq("executing")
    end

    it "can transition to completed" do
      data_room.update!(status: "completed")
      expect(data_room.status).to eq("completed")
    end

    it "can transition to failed" do
      data_room.update!(status: "failed")
      expect(data_room.status).to eq("failed")
    end
  end

  describe "#all_attested?" do
    let(:data_room) { create(:data_room) }

    context "with no participants" do
      it "returns false" do
        expect(data_room.all_attested?).to be false
      end
    end

    context "with some participants not attested" do
      before do
        create(:data_room_participant, data_room: data_room, status: "invited")
        create(:data_room_participant, data_room: data_room, status: "attested")
      end

      it "returns false" do
        expect(data_room.all_attested?).to be false
      end
    end

    context "with all participants attested" do
      before do
        create(:data_room_participant, data_room: data_room, status: "attested")
        create(:data_room_participant, data_room: data_room, status: "attested")
      end

      it "returns true" do
        expect(data_room.all_attested?).to be true
      end
    end
  end

  describe "#ready_to_execute?" do
    let(:data_room) { create(:data_room, status: "attested") }

    context "when all participants have attested and status is attested" do
      before do
        create(:data_room_participant, data_room: data_room, status: "attested")
      end

      it "returns true" do
        expect(data_room.ready_to_execute?).to be true
      end
    end

    context "when not all participants have attested" do
      before do
        create(:data_room_participant, data_room: data_room, status: "invited")
      end

      it "returns false" do
        expect(data_room.ready_to_execute?).to be false
      end
    end

    context "when status is not attested" do
      before do
        data_room.update!(status: "pending")
        create(:data_room_participant, data_room: data_room, status: "attested")
      end

      it "returns false" do
        expect(data_room.ready_to_execute?).to be false
      end
    end
  end

  describe "#participant_count" do
    let(:data_room) { create(:data_room) }

    it "returns zero when no participants" do
      expect(data_room.participant_count).to eq(0)
    end

    it "returns correct count with participants" do
      create_list(:data_room_participant, 3, data_room: data_room)
      expect(data_room.participant_count).to eq(3)
    end
  end

  describe "#attested_count" do
    let(:data_room) { create(:data_room) }

    it "returns zero when no participants" do
      expect(data_room.attested_count).to eq(0)
    end

    it "returns only attested participants" do
      create(:data_room_participant, data_room: data_room, status: "attested")
      create(:data_room_participant, data_room: data_room, status: "attested")
      create(:data_room_participant, data_room: data_room, status: "invited")
      expect(data_room.attested_count).to eq(2)
    end
  end
end
