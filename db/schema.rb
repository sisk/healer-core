# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20141002092952) do

  create_table "appointments", force: true do |t|
    t.integer  "patient_id"
    t.integer  "trip_id"
    t.datetime "start_time"
    t.integer  "start_ordinal"
    t.datetime "end_time"
    t.string   "location"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "appointments", ["patient_id"], name: "index_appointments_on_patient_id"
  add_index "appointments", ["trip_id", "start_time", "location"], name: "index_appointments_on_trip_id_and_start_time_and_location"

  create_table "attachments", force: true do |t|
    t.integer  "record_id"
    t.string   "record_type"
    t.text     "description"
    t.string   "document_file_name"
    t.string   "document_content_type"
    t.integer  "document_file_size"
    t.datetime "document_updated_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "attachments", ["record_id"], name: "index_attachments_on_record_id"
  add_index "attachments", ["record_type", "record_id"], name: "index_attachments_on_record_type_and_record_id"

  create_table "cases", force: true do |t|
    t.integer  "patient_id"
    t.string   "anatomy"
    t.string   "side"
    t.string   "status",     default: "active"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "cases", ["status"], name: "index_cases_on_status"

  create_table "patients", force: true do |t|
    t.string   "name"
    t.date     "birth"
    t.string   "gender",     limit: 10
    t.date     "death"
    t.string   "status",                default: "active"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "patients", ["name", "birth"], name: "index_patients_on_name_and_birth"
  add_index "patients", ["status"], name: "index_patients_on_status"

end
