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

ActiveRecord::Schema[8.0].define(version: 2025_11_10_231857) do
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

  create_table "ai_providers", force: :cascade do |t|
    t.string "name", null: false
    t.string "provider_type", null: false
    t.text "api_key_encrypted"
    t.jsonb "config", default: {}
    t.boolean "active", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_ai_providers_on_active"
    t.index ["provider_type"], name: "index_ai_providers_on_provider_type"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "season_id", null: false
    t.datetime "last_message_at"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_conversations_on_active"
    t.index ["last_message_at"], name: "index_conversations_on_last_message_at"
    t.index ["season_id", "active"], name: "index_conversations_on_season_active"
    t.index ["season_id"], name: "index_conversations_on_season_id"
    t.index ["user_id", "season_id"], name: "index_conversations_on_user_id_and_season_id", unique: true
    t.index ["user_id"], name: "index_conversations_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "sender_type", null: false
    t.text "content", null: false
    t.datetime "read_at"
    t.boolean "is_fragment", default: false
    t.integer "fragment_index"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_created"
    t.index ["conversation_id", "sender_type", "created_at"], name: "index_messages_on_conversation_sender_created"
    t.index ["conversation_id", "sender_type", "read_at"], name: "index_messages_on_conversation_sender_read"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["created_at"], name: "index_messages_on_created_at"
    t.index ["read_at"], name: "index_messages_on_read_at"
    t.index ["sender_type"], name: "index_messages_on_sender_type"
  end

  create_table "persona_memories", force: :cascade do |t|
    t.bigint "season_id", null: false
    t.text "content", null: false
    t.float "significance", default: 5.0, null: false
    t.float "emotional_intensity", default: 5.0, null: false
    t.float "detail_level", default: 1.0, null: false
    t.integer "recall_count", default: 0, null: false
    t.datetime "last_recalled_at"
    t.datetime "memory_timestamp", null: false
    t.string "tags", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["season_id"], name: "index_persona_memories_on_season_id"
    t.index ["significance"], name: "index_persona_memories_on_significance"
    t.index ["tags"], name: "index_persona_memories_on_tags", using: :gin
  end

  create_table "persona_states", force: :cascade do |t|
    t.bigint "season_id", null: false
    t.jsonb "state_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["season_id"], name: "index_persona_states_on_season_id"
    t.index ["state_data"], name: "index_persona_states_on_state_data", using: :gin
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "endpoint", null: false
    t.string "p256dh_key", null: false
    t.string "auth_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.integer "season_number", null: false
    t.boolean "active", default: false, null: false
    t.string "first_name"
    t.string "last_name"
    t.string "status_message"
    t.datetime "start_date", null: false
    t.datetime "end_date"
    t.datetime "deactivation_warned_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_seasons_on_active"
    t.index ["active"], name: "index_seasons_on_active_unique", unique: true, where: "(active = true)"
    t.index ["season_number"], name: "index_seasons_on_season_number", unique: true
  end

  create_table "tool_states", force: :cascade do |t|
    t.bigint "season_id", null: false
    t.string "tool_name", null: false
    t.jsonb "state_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["season_id", "tool_name"], name: "index_tool_states_on_season_id_and_tool_name", unique: true
    t.index ["season_id"], name: "index_tool_states_on_season_id"
  end

  create_table "user_states", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "conversation_id", null: false
    t.datetime "typing_at"
    t.datetime "last_seen_at"
    t.boolean "is_focused", default: false
    t.integer "scroll_position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_user_states_on_conversation_id"
    t.index ["user_id", "conversation_id"], name: "index_user_states_on_user_id_and_conversation_id", unique: true
    t.index ["user_id"], name: "index_user_states_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "device_id", null: false
    t.string "name"
    t.string "status_message"
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_users_on_device_id", unique: true
    t.index ["last_seen_at"], name: "index_users_on_last_seen_at"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "conversations", "seasons"
  add_foreign_key "conversations", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "persona_memories", "seasons"
  add_foreign_key "persona_states", "seasons"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "tool_states", "seasons"
  add_foreign_key "user_states", "conversations"
  add_foreign_key "user_states", "users"
end
