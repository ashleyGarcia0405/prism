FactoryBot.define do
  factory :user do
    association :organization
    name { "Test User" }
    email { "user_#{SecureRandom.hex(3)}@example.com" }
    password { "secure123" }
  end
end
