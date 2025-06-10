# frozen_string_literal: true

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

ActiveRecord::Schema[8.0].define(version: 20_250_609_201_152) do
  create_table 'aspace_to_folio_records', force: :cascade do |t|
    t.string 'archivesspace_instance_key'
    t.integer 'repository_id'
    t.integer 'resource_id'
    t.string 'folio_hrid'
    t.integer 'pending_update', default: 1
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['archivesspace_instance_key', 'repository_id', 'resource_id'], name: 'resource_uri', unique: true
    t.index ['folio_hrid'], name: 'index_aspace_to_folio_records_on_folio_hrid', unique: true
    t.index ['pending_update'], name: 'index_aspace_to_folio_records_on_pending_update'
  end
end
