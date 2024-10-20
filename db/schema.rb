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

ActiveRecord::Schema[7.0].define(version: 2024_10_20_211114) do
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

  create_table "contracts", force: :cascade do |t|
    t.integer "lot_id", null: false
    t.integer "creator_id"
    t.integer "applicant_user_id", null: false
    t.integer "payment_term", null: false
    t.string "financing_type", null: false
    t.string "status", default: "pending"
    t.decimal "balance"
    t.decimal "down_payment"
    t.decimal "reserve_amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["applicant_user_id"], name: "index_contracts_on_applicant_user_id"
    t.index ["creator_id"], name: "index_contracts_on_creator_id"
    t.index ["lot_id"], name: "index_contracts_on_lot_id"
  end

  create_table "lots", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "name", null: false
    t.decimal "length", precision: 10, scale: 2, null: false
    t.decimal "width", precision: 10, scale: 2, null: false
    t.decimal "price", precision: 15, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_lots_on_project_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "contracts_id", null: false
    t.decimal "amount"
    t.date "due_date"
    t.date "payment_date"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contracts_id"], name: "index_payments_on_contracts_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.text "description", null: false
    t.string "address", null: false
    t.integer "lot_count", null: false
    t.decimal "price_per_square_foot", precision: 10, scale: 2, null: false
    t.decimal "interest_rate", precision: 5, scale: 2, null: false
    t.string "guid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "contracts", "lots"
  add_foreign_key "contracts", "users", column: "applicant_user_id"
  add_foreign_key "contracts", "users", column: "creator_id"
  add_foreign_key "lots", "projects"
  add_foreign_key "payments", "contracts", column: "contracts_id"
end
