ActiveRecord::Schema[7.2].define(version: 2026_09_08_000010) do
  create_table "users", force: :cascade do |t|
    t.string "email", null: false, default: ""
    t.string "encrypted_password", null: false, default: ""
    t.datetime "remember_created_at"
    t.boolean "locked", null: false, default: false # thecore_auth_commons' add_locked_to_user
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
  add_index "users", ["email"], unique: true

  create_table "push_subscribers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "endpoint", null: false
    t.string "p256dh"
    t.string "auth"
    t.string "user_agent"
    t.datetime "expired_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
  add_index "push_subscribers", ["endpoint"], unique: true
  add_index "push_subscribers", ["user_id"]

  create_table "thecore_settings", force: :cascade do |t|
    t.boolean "enabled", default: true
    t.string "kind", null: false, default: "string"
    t.string "ns", default: "main"
    t.string "key", null: false
    t.text "raw"
    t.string "label"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
  add_index "thecore_settings", ["key"]
  add_index "thecore_settings", ["ns", "key"], unique: true

  create_table "push_messages", force: :cascade do |t|
    t.bigint "push_subscriber_id", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.string "url"
    t.string "icon"
    t.datetime "sent_at"
    t.datetime "received_at"
    t.datetime "read_at"
    t.bigint "sender_user_id"
    t.string "message_type", null: false, default: "communication"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "sent_at_time_zone"
    t.string "received_at_time_zone"
    t.string "read_at_time_zone"
  end
  add_index "push_messages", ["push_subscriber_id"]
  add_index "push_messages", ["sender_user_id"]

  # Every ApplicationRecord gets has_rich_text :rich_content and has_many_attached :assets
  # (config/initializers/concern_application_record.rb), as in production: destroying any record
  # touches these tables, so the eager-loaded CI run needs them.
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
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
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end
  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end
end
