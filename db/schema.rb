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

ActiveRecord::Schema[8.1].define(version: 2026_11_05_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "golf_courses", force: :cascade do |t|
    t.string "external_id", null: false
    t.string "name", null: false
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "address"
    t.string "course_type"
    t.string "website"
    t.integer "holes_count"
    t.integer "par_total"
    t.jsonb "scorecard", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_golf_courses_on_external_id", unique: true
    t.index ["name"], name: "index_golf_courses_on_name"
  end

  create_table "hole_scores", force: :cascade do |t|
    t.bigint "hole_id", null: false
    t.bigint "player_id", null: false
    t.integer "strokes", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hole_id", "player_id"], name: "index_hole_scores_on_hole_id_and_player_id", unique: true
    t.index ["hole_id"], name: "index_hole_scores_on_hole_id"
    t.index ["player_id"], name: "index_hole_scores_on_player_id"
    t.check_constraint "strokes >= 1 AND strokes <= 30", name: "hole_scores_strokes_range"
  end

  create_table "holes", force: :cascade do |t|
    t.bigint "round_id", null: false
    t.integer "number", null: false
    t.integer "par", default: 4, null: false
    t.integer "stroke_index", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["round_id", "number"], name: "index_holes_on_round_id_and_number", unique: true
    t.index ["round_id", "stroke_index"], name: "index_holes_on_round_id_and_stroke_index", unique: true
    t.index ["round_id"], name: "index_holes_on_round_id"
    t.check_constraint "number >= 1 AND number <= 18 AND par >= 3 AND par <= 6 AND stroke_index >= 1 AND stroke_index <= 18", name: "holes_valid_ranges"
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "trip_id", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id"], name: "index_invitations_on_trip_id"
  end

  create_table "logins", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_logins_on_user_id"
  end

  create_table "matches", force: :cascade do |t|
    t.bigint "round_id", null: false
    t.bigint "home_player_id", null: false
    t.bigint "away_player_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["away_player_id"], name: "index_matches_on_away_player_id"
    t.index ["home_player_id"], name: "index_matches_on_home_player_id"
    t.index ["round_id"], name: "index_matches_on_round_id"
    t.check_constraint "home_player_id <> away_player_id", name: "matches_distinct_players"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "trip_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "scorer", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id", "user_id"], name: "index_memberships_on_trip_id_and_user_id", unique: true
    t.index ["trip_id"], name: "index_memberships_on_trip_id"
    t.index ["trip_id"], name: "one_owner_per_trip", unique: true, where: "((role)::text = 'owner'::text)"
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['owner'::character varying, 'scorer'::character varying]::text[])", name: "memberships_valid_role"
  end

  create_table "players", force: :cascade do |t|
    t.bigint "trip_id", null: false
    t.string "name", null: false
    t.integer "playing_handicap", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "team_id"
    t.index ["team_id"], name: "index_players_on_team_id"
    t.index ["trip_id", "name"], name: "index_players_on_trip_id_and_name", unique: true
    t.index ["trip_id"], name: "index_players_on_trip_id"
    t.check_constraint "playing_handicap >= '-10'::integer AND playing_handicap <= 54", name: "players_handicap_range"
  end

  create_table "rounds", force: :cascade do |t|
    t.bigint "trip_id", null: false
    t.bigint "golf_course_id"
    t.string "course", null: false
    t.date "plays_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "scoring_mode", default: "total", null: false
    t.boolean "course_confirmed", default: false, null: false
    t.index ["golf_course_id"], name: "index_rounds_on_golf_course_id"
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

  create_table "teams", force: :cascade do |t|
    t.bigint "trip_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id", "name"], name: "index_teams_on_trip_id_and_name", unique: true
    t.index ["trip_id"], name: "index_teams_on_trip_id"
  end

  create_table "trips", force: :cascade do |t|
    t.string "name", null: false
    t.string "destination", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "recovery_code_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "hole_scores", "holes"
  add_foreign_key "hole_scores", "players"
  add_foreign_key "holes", "rounds"
  add_foreign_key "invitations", "trips"
  add_foreign_key "logins", "users"
  add_foreign_key "matches", "players", column: "away_player_id"
  add_foreign_key "matches", "players", column: "home_player_id"
  add_foreign_key "matches", "rounds"
  add_foreign_key "memberships", "trips"
  add_foreign_key "memberships", "users"
  add_foreign_key "players", "teams"
  add_foreign_key "players", "trips"
  add_foreign_key "rounds", "golf_courses"
  add_foreign_key "rounds", "trips"
  add_foreign_key "scores", "players"
  add_foreign_key "scores", "rounds"
  add_foreign_key "teams", "trips"
end
