# frozen_string_literal: true

class CreateSolidQueueTables < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:solid_queue_jobs)

    create_table :solid_queue_jobs do |t|
      t.string :queue_name, null: false
      t.string :class_name, null: false
      t.text :arguments
      t.integer :priority, null: false, default: 0
      t.string :active_job_id
      t.datetime :scheduled_at
      t.datetime :finished_at
      t.string :concurrency_key
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :active_job_id
      t.index :class_name
      t.index :finished_at
      t.index %i[queue_name finished_at], name: "index_solid_queue_jobs_for_filtering"
      t.index %i[scheduled_at finished_at], name: "index_solid_queue_jobs_for_alerting"
    end

    create_table :solid_queue_blocked_executions do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, null: false, default: 0
      t.string :concurrency_key, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false

      t.index %i[concurrency_key priority job_id], name: "index_solid_queue_blocked_executions_for_release"
      t.index %i[expires_at concurrency_key], name: "index_solid_queue_blocked_executions_for_maintenance"
      t.index :job_id, unique: true
    end

    create_table :solid_queue_claimed_executions do |t|
      t.bigint :job_id, null: false
      t.bigint :process_id
      t.datetime :created_at, null: false

      t.index :job_id, unique: true
      t.index %i[process_id job_id], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
    end

    create_table :solid_queue_failed_executions do |t|
      t.bigint :job_id, null: false
      t.text :error
      t.datetime :created_at, null: false

      t.index :job_id, unique: true
    end

    create_table :solid_queue_ready_executions do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, null: false, default: 0
      t.datetime :created_at, null: false

      t.index :job_id, unique: true
      t.index %i[priority job_id], name: "index_solid_queue_poll_all"
      t.index %i[queue_name priority job_id], name: "index_solid_queue_poll_by_queue"
    end

    create_table :solid_queue_recurring_tasks do |t|
      t.string :key, null: false
      t.string :schedule, null: false
      t.string :class_name, null: false
      t.text :arguments
      t.string :queue_name, null: false
      t.integer :priority, null: false, default: 0
      t.boolean :static, null: false, default: false
      t.integer :concurrency, null: false, default: 1
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :key, unique: true
      t.index :static
    end

    create_table :solid_queue_recurring_executions do |t|
      t.bigint :job_id, null: false
      t.string :task_key, null: false
      t.datetime :run_at, null: false
      t.datetime :created_at, null: false

      t.index :job_id, unique: true
      t.index %i[task_key run_at], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
    end

    create_table :solid_queue_processes do |t|
      t.string :kind, null: false
      t.string :name, null: false
      t.bigint :supervisor_id
      t.datetime :last_heartbeat_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :last_heartbeat_at
      t.index %i[name supervisor_id], unique: true
      t.index :supervisor_id
    end

    create_table :solid_queue_pauses do |t|
      t.string :queue_name, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :queue_name, unique: true
    end

    create_table :solid_queue_scheduled_executions do |t|
      t.bigint :job_id, null: false
      t.integer :priority, null: false, default: 0
      t.datetime :scheduled_at, null: false
      t.datetime :created_at, null: false

      t.index :job_id, unique: true
      t.index %i[scheduled_at priority job_id], name: "index_solid_queue_dispatch_all"
    end

    create_table :solid_queue_semaphores do |t|
      t.string :key, null: false
      t.string :value, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :key, unique: true
      t.index %i[key value], name: "index_solid_queue_semaphores_on_key_and_value"
      t.index :expires_at
    end

    add_foreign_key :solid_queue_blocked_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade
    add_foreign_key :solid_queue_claimed_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade
    add_foreign_key :solid_queue_failed_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade
    add_foreign_key :solid_queue_ready_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade
    add_foreign_key :solid_queue_recurring_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade
    add_foreign_key :solid_queue_scheduled_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade
  end
end
