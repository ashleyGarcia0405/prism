# frozen_string_literal: true

FactoryBot.define do
  factory :data_room_invitation do
    association :data_room
    association :organization
    association :invited_by, factory: :user
    status { "pending" }
    invitation_token { SecureRandom.urlsafe_base64(32) }
    expires_at { 7.days.from_now }

    trait :accepted do
      status { "accepted" }
    end

    trait :declined do
      status { "declined" }
    end

    trait :expired do
      status { "expired" }
      expires_at { 1.day.ago }
    end
  end
end