FactoryBot.define do
  factory :organization do
    name { "Org #{SecureRandom.hex(2)}" }
  end
end
