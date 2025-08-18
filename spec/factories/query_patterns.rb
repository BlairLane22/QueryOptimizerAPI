FactoryBot.define do
  factory :query_pattern do
    pattern_type { "MyString" }
    table_name { "MyString" }
    column_name { "MyString" }
    frequency { 1 }
    first_seen { "2025-08-18 17:47:40" }
    last_seen { "2025-08-18 17:47:40" }
  end
end
