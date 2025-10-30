FactoryBot.define do
  factory :query do
    association :dataset
    association :user
    sql { "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25" }
    estimated_epsilon { "0.1" }
  end
end
