# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataRoomInvitation, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:data_room) }
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:invited_by).class_name("User") }
  end

  describe "validations" do
    subject { build(:data_room_invitation) }

    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_uniqueness_of(:invitation_token) }

    it "validates status inclusion" do
      invitation = build(:data_room_invitation)
      expect {
        invitation.update(status: "invalid")
      }.to raise_error(ArgumentError, /'invalid' is not a valid status/)
    end
  end

  describe "callbacks" do
    describe "before_validation on create" do
      let(:invitation) { build(:data_room_invitation, invitation_token: nil, expires_at: nil) }

      it "generates invitation_token if not present" do
        invitation.save
        expect(invitation.invitation_token).to be_present
        expect(invitation.invitation_token.length).to be > 20
      end

      it "sets expires_at to 7 days from now if not present" do
        invitation.save
        expect(invitation.expires_at).to be_within(1.second).of(7.days.from_now)
      end

      it "does not override existing invitation_token" do
        custom_token = "custom_token_123"
        invitation.invitation_token = custom_token
        invitation.save
        expect(invitation.invitation_token).to eq(custom_token)
      end

      it "does not override existing expires_at" do
        custom_expiry = 3.days.from_now
        invitation.expires_at = custom_expiry
        invitation.save
        expect(invitation.expires_at).to be_within(1.second).of(custom_expiry)
      end
    end
  end

  describe "status transitions" do
    let(:invitation) { create(:data_room_invitation) }

    it "has pending status by default" do
      expect(invitation.status).to eq("pending")
    end

    it "can transition to accepted" do
      invitation.update!(status: "accepted")
      expect(invitation.status).to eq("accepted")
    end

    it "can transition to declined" do
      invitation.update!(status: "declined")
      expect(invitation.status).to eq("declined")
    end

    it "can transition to expired" do
      invitation.update!(status: "expired")
      expect(invitation.status).to eq("expired")
    end
  end

  describe "#expired?" do
    context "when expires_at is in the future" do
      let(:invitation) { create(:data_room_invitation, expires_at: 1.day.from_now) }

      it "returns false" do
        expect(invitation.expired?).to be false
      end
    end

    context "when expires_at is in the past" do
      let(:invitation) { create(:data_room_invitation, expires_at: 1.day.ago) }

      it "returns true" do
        expect(invitation.expired?).to be true
      end
    end

    context "when expires_at is nil" do
      let(:invitation) { create(:data_room_invitation, expires_at: nil) }

      it "returns false" do
        expect(invitation.expired?).to be false
      end
    end
  end

  describe "#accept!" do
    let(:data_room) { create(:data_room) }
    let(:organization) { create(:organization) }
    let(:dataset) { create(:dataset, organization: organization) }
    let(:invitation) { create(:data_room_invitation, data_room: data_room, organization: organization) }

    context "when invitation is not expired" do
      it "updates status to accepted" do
        invitation.accept!(dataset)
        expect(invitation.reload.status).to eq("accepted")
      end

      it "creates a participant" do
        expect {
          invitation.accept!(dataset)
        }.to change(DataRoomParticipant, :count).by(1)
      end

      it "associates participant with correct data" do
        invitation.accept!(dataset)
        participant = DataRoomParticipant.last
        expect(participant.data_room).to eq(data_room)
        expect(participant.organization).to eq(organization)
        expect(participant.dataset).to eq(dataset)
        expect(participant.status).to eq("invited")
      end

      it "returns true" do
        expect(invitation.accept!(dataset)).to be true
      end
    end

    context "when invitation is expired" do
      let(:invitation) { create(:data_room_invitation, :expired, data_room: data_room, organization: organization) }

      it "does not update status" do
        invitation.accept!(dataset)
        expect(invitation.reload.status).to eq("expired")
      end

      it "does not create a participant" do
        expect {
          invitation.accept!(dataset)
        }.not_to change(DataRoomParticipant, :count)
      end

      it "returns false" do
        expect(invitation.accept!(dataset)).to be false
      end
    end
  end

  describe "#decline!" do
    let(:invitation) { create(:data_room_invitation, status: "pending") }

    it "updates status to declined" do
      invitation.decline!
      expect(invitation.status).to eq("declined")
    end
  end
end
