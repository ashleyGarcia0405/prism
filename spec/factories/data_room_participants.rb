# frozen_string_literal: true

FactoryBot.define do
  factory :data_room_participant do
    association :data_room
    association :organization
    association :dataset
    status { "invited" }

    trait :attested do
      status { "attested" }
      attested_at { Time.current }
    end

    trait :computed do
      status { "computed" }
      attested_at { 1.hour.ago }
      computed_at { Time.current }
      computation_metadata do
        {
          protocol: "shamirs_secret_sharing",
          num_parties: 3,
          mocked: true
        }
      end
    end

    trait :declined do
      status { "declined" }
    end
  end
end