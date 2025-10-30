FactoryBot.define do
  factory :dataset do
    association :organization
    name { "Dataset #{SecureRandom.hex(2)}" }
  end
end
