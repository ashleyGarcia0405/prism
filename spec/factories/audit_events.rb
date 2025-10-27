FactoryBot.define do
  factory :audit_event do
    action { "MyString" }
    user { nil }
    target_type { "MyString" }
    target_id { 1 }
  end
end
