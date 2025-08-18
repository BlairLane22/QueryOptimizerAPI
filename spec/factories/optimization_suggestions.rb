FactoryBot.define do
  factory :optimization_suggestion do
    association :query_analysis
    suggestion_type { "n_plus_one" }
    title { "Fix N+1 Query" }
    description { "Use includes to preload associations" }
    sql_suggestion { "User.includes(:posts).where(...)" }
    priority { 2 }
    implemented { false }
    metadata { {} }
  end
end
