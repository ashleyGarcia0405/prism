FactoryBot.define do
  factory :run do
    association :query
    association :user
    status { "pending" }
  end
end
