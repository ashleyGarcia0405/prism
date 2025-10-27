FactoryBot.define do
  factory :query do
    sql { "MyText" }
    dataset { nil }
    user { nil }
  end
end
