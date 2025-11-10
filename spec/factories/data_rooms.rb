# frozen_string_literal: true

FactoryBot.define do
  factory :data_room do
    association :creator, factory: :user
    name { Faker::Company.name + " Data Room" }
    description { Faker::Lorem.sentence }
    query_text { "SELECT COUNT(*) FROM data GROUP BY category HAVING COUNT(*) >= 25" }
    query_type { "count" }
    status { "pending" }

    trait :attested do
      status { "attested" }
    end

    trait :executing do
      status { "executing" }
    end

    trait :completed do
      status { "completed" }
      executed_at { Time.current }
      result { { count: rand(100..1000) } }
    end

    trait :failed do
      status { "failed" }
    end
  end
end