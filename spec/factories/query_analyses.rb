FactoryBot.define do
  factory :query_analysis do
    association :app_profile
    sql_query { "SELECT * FROM users WHERE id = 1" }
    duration_ms { rand(10..500) }
    table_name { "users" }
    query_type { "SELECT" }
    analyzed_at { Time.current }
  end
end
