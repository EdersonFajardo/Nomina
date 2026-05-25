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

ActiveRecord::Schema[8.1].define(version: 2026_05_08_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "companies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "last_payroll_consecutive", default: 0, null: false
    t.string "name", null: false
    t.string "nit", null: false
    t.string "payroll_code"
    t.string "payroll_prefix", default: "NM"
    t.datetime "updated_at", null: false
    t.index ["nit"], name: "index_companies_on_nit", unique: true
  end

  create_table "contracts", force: :cascade do |t|
    t.string "area"
    t.date "arl_date"
    t.string "arl_entity"
    t.string "bank_account"
    t.string "bank_name"
    t.decimal "basic_salary", precision: 12, scale: 2
    t.string "compensation_fund"
    t.date "contract_date"
    t.date "contract_end_date"
    t.string "contract_number"
    t.integer "contract_type", default: 3, null: false
    t.datetime "created_at", null: false
    t.bigint "employee_id", null: false
    t.date "health_date"
    t.string "health_entity"
    t.date "hire_date"
    t.boolean "integral_salary", default: false, null: false
    t.date "pension_date"
    t.string "pension_entity"
    t.string "position"
    t.string "severance_fund"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.date "vacation_date"
    t.index ["employee_id", "contract_number"], name: "index_contracts_on_employee_id_and_contract_number", unique: true
    t.index ["employee_id"], name: "index_contracts_on_employee_id"
  end

  create_table "conversion_logs", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.integer "month", null: false
    t.string "provisions_file_name"
    t.string "syscafe_file_name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "year", null: false
    t.index ["company_id"], name: "index_conversion_logs_on_company_id"
    t.index ["user_id"], name: "index_conversion_logs_on_user_id"
  end

  create_table "documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "file_name", null: false
    t.string "source_format", null: false
    t.string "target_format", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "email_accounts", force: :cascade do |t|
    t.text "access_token"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "history_id"
    t.text "last_sync_error"
    t.datetime "last_synced_at"
    t.string "provider", default: "gmail", null: false
    t.text "refresh_token"
    t.string "scopes"
    t.string "sync_status", default: "pending", null: false
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "email"], name: "index_email_accounts_on_user_id_and_email", unique: true
    t.index ["user_id"], name: "index_email_accounts_on_user_id"
  end

  create_table "employees", force: :cascade do |t|
    t.string "address", default: "BOGOTA", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.integer "department", default: 11, null: false
    t.string "document_number", null: false
    t.integer "document_type", default: 13, null: false
    t.string "email"
    t.string "first_name", null: false
    t.string "first_surname", null: false
    t.string "gender"
    t.string "mobile"
    t.integer "municipality", default: 11001, null: false
    t.string "other_names"
    t.string "phone"
    t.string "second_surname"
    t.datetime "updated_at", null: false
    t.index ["company_id", "document_number"], name: "index_employees_on_company_id_and_document_number", unique: true
    t.index ["company_id"], name: "index_employees_on_company_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "contracts", "employees"
  add_foreign_key "conversion_logs", "companies"
  add_foreign_key "conversion_logs", "users"
  add_foreign_key "documents", "users"
  add_foreign_key "email_accounts", "users"
  add_foreign_key "employees", "companies"
end
