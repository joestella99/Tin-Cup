require "test_helper"

class ScorecardImportFlowTest < ActionDispatch::IntegrationTest
  setup do
    @old_password = ENV["ORGANIZER_PASSWORD"]
    ENV["ORGANIZER_PASSWORD"] = "test-only-import"
    post session_path, params: { password: ENV["ORGANIZER_PASSWORD"] }
    @trip = build_trip
    @a = @trip.players.create!(name: "Joe", playing_handicap: 8)
    @b = @trip.players.create!(name: "Matt", playing_handicap: 3)
    @round = @trip.rounds.create!(course: "No. 2", plays_on: @trip.starts_on, scoring_mode: :hole_by_hole)
    @round.update!(course_confirmed: true)
  end
  teardown { ENV["ORGANIZER_PASSWORD"] = @old_password }

  test "preview and import 18 scores without changing others" do
    hole = @round.holes.find_by!(number: 1)
    hole.hole_scores.create!(player: @b, strokes: 5)
    text = (1..18).map { |n| (n % 3) + 3 }.join(",")
    get new_trip_round_scorecard_import_path(@trip, @round)
    assert_response :success
    assert_select "#scores_text"
    post trip_round_scorecard_import_path(@trip, @round), params: { player_id: @a.id, scores_text: text }
    assert_response :success
    assert_select ".score-import-table tbody tr", count: 18
    assert_equal 0, @round.hole_scores.where(player: @a).count
    post trip_round_scorecard_import_path(@trip, @round),
      params: { player_id: @a.id, import_values: text, confirm: "1" }
    assert_redirected_to trip_round_path(@trip, @round, player_id: @a.id)
    assert_equal 18, @round.hole_scores.where(player: @a).count
    assert_equal 5, hole.hole_scores.find_by!(player: @b).strokes
    assert_equal 4, hole.hole_scores.find_by!(player: @a).strokes
  end

  test "existing cards need explicit overwrite approval" do
    hole = @round.holes.first
    hole.hole_scores.create!(player: @a, strokes: 6)
    scores = ([4] * 18).join(",")
    post trip_round_scorecard_import_path(@trip, @round),
      params: { player_id: @a.id, import_values: scores, confirm: "1" }
    assert_response :unprocessable_entity
    assert_equal 6, hole.hole_scores.find_by!(player: @a).strokes
    post trip_round_scorecard_import_path(@trip, @round),
      params: { player_id: @a.id, import_values: scores, confirm: "1", replace_existing: "1" }
    assert_redirected_to trip_round_path(@trip, @round, player_id: @a.id)
    assert_equal 4, hole.hole_scores.find_by!(player: @a).strokes
  end

  test "unconfirmed and unauthorized rounds can't import" do
    @round.update!(course_confirmed: false)
    get new_trip_round_scorecard_import_path(@trip, @round)
    assert_response :not_found
    post trip_round_scorecard_import_path(@trip, @round),
      params: { player_id: @a.id, scores_text: ([4] * 18).join(",") }
    assert_response :not_found
    @round.update!(course_confirmed: true)
    delete session_path
    post trip_round_scorecard_import_path(@trip, @round),
      params: { player_id: @a.id, scores_text: ([4] * 18).join(",") }
    assert_redirected_to new_session_path
  end

  test "invalid scorecard never saves partial data" do
    post trip_round_scorecard_import_path(@trip, @round),
      params: { player_id: @a.id, import_values: ([4] * 17 + [31]).join(","), confirm: "1" }
    assert_response :unprocessable_entity
    assert_empty @round.hole_scores.where(player: @a)
  end
end
