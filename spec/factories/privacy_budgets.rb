FactoryBot.define do
  factory :privacy_budget do
    dataset
    total_epsilon { 3.0 }
    consumed_epsilon { 0.0 }
    reserved_epsilon { 0.0 }
  end
end
