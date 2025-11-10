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

ActiveRecord::Schema[8.0].define(version: 2025_11_10_035159) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_events", force: :cascade do |t|
    t.string "action"
    t.bigint "user_id", null: false
    t.string "target_type"
    t.integer "target_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.index ["action"], name: "index_audit_events_on_action"
    t.index ["created_at"], name: "index_audit_events_on_created_at"
    t.index ["metadata"], name: "index_audit_events_on_metadata", using: :gin
    t.index ["target_type", "target_id"], name: "index_audit_events_on_target_type_and_target_id"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "datasets", force: :cascade do |t|
    t.string "name"
    t.bigint "organization_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.index ["organization_id"], name: "index_datasets_on_organization_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "policies", force: :cascade do |t|
    t.string "name"
    t.bigint "organization_id", null: false
    t.text "rules"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_policies_on_organization_id"
  end

  create_table "privacy_budgets", force: :cascade do |t|
    t.bigint "dataset_id", null: false
    t.decimal "total_epsilon", precision: 10, scale: 6, default: "3.0", null: false
    t.decimal "consumed_epsilon", precision: 10, scale: 6, default: "0.0", null: false
    t.decimal "reserved_epsilon", precision: 10, scale: 6, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dataset_id"], name: "index_privacy_budgets_on_dataset_id", unique: true
  end

  create_table "queries", force: :cascade do |t|
    t.text "sql"
    t.bigint "dataset_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "estimated_epsilon", precision: 10, scale: 6
    t.decimal "delta", precision: 10, scale: 10, default: "0.00001"
    t.string "backend", default: "dp_sandbox", null: false
    t.index ["backend"], name: "index_queries_on_backend"
    t.index ["dataset_id"], name: "index_queries_on_dataset_id"
    t.index ["user_id"], name: "index_queries_on_user_id"
  end

  create_table "runs", force: :cascade do |t|
    t.bigint "query_id", null: false
    t.string "status"
    t.text "result"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "backend_used"
    t.decimal "epsilon_consumed", precision: 10, scale: 6
    t.jsonb "proof_artifacts", default: {}
    t.integer "execution_time_ms"
    t.text "error_message"
    t.bigint "user_id"
    t.decimal "delta_consumed", precision: 10, scale: 10
    t.index ["backend_used"], name: "index_runs_on_backend_used"
    t.index ["query_id"], name: "index_runs_on_query_id"
    t.index ["status"], name: "index_runs_on_status"
    t.index ["user_id"], name: "index_runs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "password_digest"
    t.bigint "organization_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  add_foreign_key "audit_events", "users"
  add_foreign_key "datasets", "organizations"
  add_foreign_key "policies", "organizations"
  add_foreign_key "privacy_budgets", "datasets"
  add_foreign_key "queries", "datasets"
  add_foreign_key "queries", "users"
  add_foreign_key "runs", "queries"
  add_foreign_key "runs", "users"
  add_foreign_key "users", "organizations"
end
