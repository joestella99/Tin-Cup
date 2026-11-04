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

ActiveRecord::Schema[8.1].define(version: 2026_11_04_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "players", force: :cascade do |t|
    t.bigint "trip_id", null: false
    t.string "name", null: false
    t.integer "playing_handicap", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id", "name"], name: "index_players_on_trip_id_and_name", unique: true
    t.index ["trip_id"], name: "index_players_on_trip_id"
    t.check_constraint "playing_handicap >= '-10'::integer AND playing_handicap <= 54", name: "players_handicap_range"
  end

  create_table "rounds", force: :cascade do |t|
    t.bigint "trip_id", null: false
    t.string "course", null: false
    t.date "plays_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id"], name: "index_rounds_on_trip_id"
  end

  create_table "scores", force: :cascade do |t|
    t.bigint "round_id", null: false
    t.bigint "player_id", null: false
    t.integer "gross", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_scores_on_player_id"
    t.index ["round_id", "player_id"], name: "index_scores_on_round_id_and_player_id", unique: true
    t.index ["round_id"], name: "index_scores_on_round_id"
    t.check_constraint "gross > 0", name: "scores_positive_gross"
  end

  create_table "trips", force: :cascade do |t|
    t.string "name", null: false
    t.string "destination", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "players", "trips"
  add_foreign_key "rounds", "trips"
  add_foreign_key "scores", "players"
  add_foreign_key "scores", "rounds"
end
