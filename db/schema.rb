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

ActiveRecord::Schema[8.0].define(version: 2025_10_28_082902) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "contract_ledger_entries", force: :cascade do |t|
    t.bigint "contract_id", null: false
    t.bigint "payment_id"
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.string "description", null: false
    t.string "entry_type", null: false
    t.datetime "entry_date", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_id", "entry_date"], name: "index_contract_ledger_entries_on_contract_id_and_entry_date"
    t.index ["contract_id"], name: "index_contract_ledger_entries_on_contract_id"
    t.index ["payment_id"], name: "index_contract_ledger_entries_on_payment_id"
  end

  create_table "contracts", force: :cascade do |t|
    t.bigint "lot_id", null: false
    t.bigint "creator_id"
    t.bigint "applicant_user_id", null: false
    t.integer "payment_term", null: false
    t.string "financing_type", null: false
    t.string "status", default: "pending"
    t.decimal "amount"
    t.decimal "balance"
    t.decimal "down_payment"
    t.decimal "reserve_amount"
    t.string "currency", default: "HNL", null: false
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: false, null: false
    t.text "note"
    t.text "rejection_reason"
    t.datetime "closed_at"
    t.index ["active"], name: "index_contracts_on_active"
    t.index ["applicant_user_id"], name: "index_contracts_on_applicant_user_id"
    t.index ["approved_at"], name: "index_contracts_on_approved_at"
    t.index ["creator_id"], name: "index_contracts_on_creator_id"
    t.index ["lot_id"], name: "index_contracts_on_lot_id"
    t.index ["status", "active"], name: "index_contracts_on_status_and_active"
    t.index ["status"], name: "index_contracts_on_status"
  end

  create_table "lots", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "name", null: false
    t.string "status", default: "available"
    t.decimal "length", precision: 10, scale: 2, null: false
    t.decimal "width", precision: 10, scale: 2, null: false
    t.decimal "price", precision: 15, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "address"
    t.string "measurement_unit"
    t.decimal "override_price", precision: 15, scale: 2
    t.string "registration_number"
    t.text "note"
    t.decimal "override_area"
    t.text "north"
    t.text "east"
    t.text "west"
    t.string "south"
    t.index ["name"], name: "index_lots_on_name"
    t.index ["project_id"], name: "index_lots_on_project_id"
    t.index ["registration_number"], name: "index_lots_on_registration_number"
    t.index ["status"], name: "index_lots_on_status"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.string "message", null: false
    t.string "notification_type"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["read_at"], name: "index_notifications_on_read_at"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "contract_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.decimal "paid_amount", precision: 15, scale: 2, default: "0.0"
    t.date "due_date", null: false
    t.date "payment_date"
    t.string "status", default: "pending", null: false
    t.string "payment_type", default: "installment"
    t.string "description"
    t.decimal "interest_amount", precision: 10, scale: 2
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_at"], name: "index_payments_on_approved_at"
    t.index ["contract_id"], name: "index_payments_on_contract_id"
    t.index ["created_at"], name: "index_payments_on_created_at"
    t.index ["due_date"], name: "index_payments_on_due_date"
    t.index ["payment_type"], name: "index_payments_on_payment_type"
    t.index ["status", "due_date"], name: "index_payments_on_status_and_due_date"
    t.index ["status"], name: "index_payments_on_status"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.text "description", null: false
    t.string "project_type", default: "residential"
    t.string "address", null: false
    t.integer "lot_count", null: false
    t.decimal "price_per_square_unit", precision: 10, scale: 2, null: false
    t.decimal "interest_rate", precision: 5, scale: 2, null: false
    t.string "guid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "commission_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.string "measurement_unit", default: "m2", null: false
    t.date "delivery_date"
    t.index ["name"], name: "index_projects_on_name"
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "revenues", force: :cascade do |t|
    t.string "payment_type", null: false
    t.integer "year", null: false
    t.integer "month", null: false
    t.decimal "amount", precision: 15, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_type", "year", "month"], name: "index_revenues_on_payment_type_and_year_and_month", unique: true
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

  create_table "statistics", force: :cascade do |t|
    t.date "period_date", null: false
    t.decimal "total_income", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "total_interest", precision: 15, scale: 2, default: "0.0", null: false
    t.integer "new_customers", default: 0, null: false
    t.decimal "payment_reserve", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "payment_installments", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "payment_down_payment", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "on_time_payment", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "delayed_payment", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "new_contracts"
    t.decimal "total_income_growth", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_interest_growth", precision: 10, scale: 2, default: "0.0"
    t.decimal "new_customers_growth", precision: 10, scale: 2, default: "0.0"
    t.decimal "new_contracts_growth", precision: 10, scale: 2, default: "0.0"
    t.decimal "payment_capital_repayment"
    t.index ["created_at"], name: "index_statistics_on_created_at"
    t.index ["period_date"], name: "index_statistics_on_period_date", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "user"
    t.string "full_name"
    t.string "phone"
    t.string "status", default: "active"
    t.string "password_digest"
    t.string "identity"
    t.string "rtn"
    t.datetime "discarded_at"
    t.string "recovery_code"
    t.datetime "recovery_code_sent_at"
    t.string "address"
    t.bigint "created_by"
    t.text "note"
    t.integer "credit_score", default: 0, null: false
    t.string "locale", default: "es", null: false
    t.index ["created_by"], name: "index_users_on_created_by"
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["full_name"], name: "index_users_on_full_name"
    t.index ["identity"], name: "index_users_on_identity", unique: true
    t.index ["locale"], name: "index_users_on_locale"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["rtn"], name: "index_users_on_rtn", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.string "ip"
    t.string "user_agent"
    t.index ["ip"], name: "index_versions_on_ip"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["user_agent"], name: "index_versions_on_user_agent"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "contract_ledger_entries", "contracts"
  add_foreign_key "contract_ledger_entries", "payments"
  add_foreign_key "contracts", "lots"
  add_foreign_key "contracts", "users", column: "applicant_user_id"
  add_foreign_key "contracts", "users", column: "creator_id"
  add_foreign_key "lots", "projects"
  add_foreign_key "notifications", "users"
  add_foreign_key "payments", "contracts"
  add_foreign_key "refresh_tokens", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "users", "users", column: "created_by"
end
