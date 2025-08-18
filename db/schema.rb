# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_18_214805) do
  create_table "app_profiles", force: :cascade do |t|
    t.string "name", null: false
    t.string "api_key_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_key_digest"], name: "index_app_profiles_on_api_key_digest", unique: true
    t.index ["name"], name: "index_app_profiles_on_name"
  end

  create_table "optimization_suggestions", force: :cascade do |t|
    t.integer "query_analysis_id", null: false
    t.string "suggestion_type", null: false
    t.string "title", null: false
    t.text "description", null: false
    t.text "sql_suggestion"
    t.integer "priority", default: 1
    t.boolean "implemented", default: false
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["implemented"], name: "index_optimization_suggestions_on_implemented"
    t.index ["priority"], name: "index_optimization_suggestions_on_priority"
    t.index ["query_analysis_id"], name: "index_optimization_suggestions_on_query_analysis_id"
    t.index ["suggestion_type"], name: "index_optimization_suggestions_on_suggestion_type"
  end

  create_table "query_analyses", force: :cascade do |t|
    t.integer "app_profile_id", null: false
    t.text "sql_query", null: false
    t.integer "duration_ms"
    t.string "table_name"
    t.string "query_type"
    t.datetime "analyzed_at", null: false
    t.string "query_hash"
    t.json "parsed_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analyzed_at"], name: "index_query_analyses_on_analyzed_at"
    t.index ["app_profile_id"], name: "index_query_analyses_on_app_profile_id"
    t.index ["duration_ms"], name: "index_query_analyses_on_duration_ms"
    t.index ["query_hash"], name: "index_query_analyses_on_query_hash"
    t.index ["query_type"], name: "index_query_analyses_on_query_type"
    t.index ["table_name"], name: "index_query_analyses_on_table_name"
  end

  create_table "query_patterns", force: :cascade do |t|
    t.string "pattern_type", null: false
    t.string "table_name", null: false
    t.string "column_name"
    t.integer "frequency", default: 1
    t.datetime "first_seen", null: false
    t.datetime "last_seen", null: false
    t.string "pattern_signature"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["frequency"], name: "index_query_patterns_on_frequency"
    t.index ["pattern_signature"], name: "index_query_patterns_on_pattern_signature", unique: true
    t.index ["pattern_type", "table_name"], name: "index_query_patterns_on_pattern_type_and_table_name"
    t.index ["pattern_type"], name: "index_query_patterns_on_pattern_type"
    t.index ["table_name"], name: "index_query_patterns_on_table_name"
  end

  add_foreign_key "optimization_suggestions", "query_analyses"
  add_foreign_key "query_analyses", "app_profiles"
end
