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

ActiveRecord::Schema[8.0].define(version: 2025_11_10_050517) do
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

  create_table "data_room_invitations", force: :cascade do |t|
    t.bigint "data_room_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "invited_by_id", null: false
    t.string "status", default: "pending", null: false
    t.string "invitation_token", null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_room_id"], name: "index_data_room_invitations_on_data_room_id"
    t.index ["invitation_token"], name: "index_data_room_invitations_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_data_room_invitations_on_invited_by_id"
    t.index ["organization_id"], name: "index_data_room_invitations_on_organization_id"
  end

  create_table "data_room_participants", force: :cascade do |t|
    t.bigint "data_room_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "dataset_id", null: false
    t.string "status", default: "invited", null: false
    t.datetime "attested_at"
    t.datetime "computed_at"
    t.jsonb "computation_metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_room_id", "organization_id"], name: "index_participants_on_room_and_org", unique: true
    t.index ["data_room_id"], name: "index_data_room_participants_on_data_room_id"
    t.index ["dataset_id"], name: "index_data_room_participants_on_dataset_id"
    t.index ["organization_id"], name: "index_data_room_participants_on_organization_id"
  end

  create_table "data_rooms", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "creator_id", null: false
    t.string "status", default: "pending", null: false
    t.text "query_text", null: false
    t.string "query_type"
    t.jsonb "query_params"
    t.jsonb "result"
    t.datetime "executed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_data_rooms_on_creator_id"
  end

  create_table "datasets", force: :cascade do |t|
    t.string "name"
    t.bigint "organization_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.string "table_name"
    t.integer "row_count", default: 0, null: false
    t.jsonb "columns", default: [], null: false
    t.string "original_filename"
    t.index ["organization_id"], name: "index_datasets_on_organization_id"
    t.index ["table_name"], name: "index_datasets_on_table_name", unique: true
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

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
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
  add_foreign_key "data_room_invitations", "data_rooms"
  add_foreign_key "data_room_invitations", "organizations"
  add_foreign_key "data_room_invitations", "users", column: "invited_by_id"
  add_foreign_key "data_room_participants", "data_rooms"
  add_foreign_key "data_room_participants", "datasets"
  add_foreign_key "data_room_participants", "organizations"
  add_foreign_key "data_rooms", "users", column: "creator_id"
  add_foreign_key "datasets", "organizations"
  add_foreign_key "policies", "organizations"
  add_foreign_key "privacy_budgets", "datasets"
  add_foreign_key "queries", "datasets"
  add_foreign_key "queries", "users"
  add_foreign_key "runs", "queries"
  add_foreign_key "runs", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "users", "organizations"
end
