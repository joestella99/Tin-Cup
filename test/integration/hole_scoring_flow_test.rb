require "test_helper"

class HoleScoringFlowTest < ActionDispatch::IntegrationTest
  setup do
    @old_password = ENV["ORGANIZER_PASSWORD"]
    ENV["ORGANIZER_PASSWORD"] = "local-test-only"
    post session_path, params: { password: ENV["ORGANIZER_PASSWORD"] }
    @trip = Trip.create!(name: "Cup", destination: "Pinehurst", starts_on: "2027-05-01", ends_on: "2027-05-03")
    @a = @trip.players.create!(name: "A", playing_handicap: 0)
    @b = @trip.players.create!(name: "B", playing_handicap: 0)
    @round = @trip.rounds.create!(course: "Course", plays_on: @trip.starts_on, scoring_mode: :hole_by_hole)
  end
  teardown { ENV["ORGANIZER_PASSWORD"] = @old_password }

  test "organizer creates teams, confirms course, pairs players and saves a hole" do
    %w[One Two Three].each { |name| post trip_teams_path(@trip), params: { team: { name: name } } }
    patch trip_player_path(@trip, @a), params: { player: { team_id: @trip.teams.first.id } }
    patch trip_player_path(@trip, @b), params: { player: { team_id: @trip.teams.second.id } }
    card = @round.holes.to_h { |hole| [ hole.id.to_s, { par: 4, stroke_index: 19 - hole.number } ] }
    patch trip_round_course_card_path(@trip, @round), params: { holes: card }
    assert @round.reload.course_confirmed?
    assert_equal 18, @round.holes.find_by!(number: 1).stroke_index
    post trip_round_matches_path(@trip, @round), params: { match: { home_player_id: @a.id, away_player_id: @b.id } }
    assert_equal 1, @round.matches.count
    hole = @round.holes.find_by!(number: 1)
    patch trip_round_hole_hole_scores_path(@trip, @round, hole), params: { strokes: { @a.id.to_s => 4, @b.id.to_s => 5 } }
    assert_equal 2, hole.hole_scores.count
    get trip_round_path(@trip, @round, hole: 1)
    assert_response :success
    assert_select ".match-status.live", text: "LIVE"
    get trip_path(@trip)
    assert_response :success
    assert_select ".team-tile", count: 3
    get edit_trip_round_course_card_path(@trip, @round)
    assert_response :success
    assert_select "input[disabled]"
  end

  test "unplayed pairings can be removed without locking players into a team" do
    teams = %w[Red Blue].map { |name| @trip.teams.create!(name: name) }
    @a.update!(team: teams.first)
    @b.update!(team: teams.last)
    @round.update!(course_confirmed: true)
    match = @round.matches.create!(home_player: @a, away_player: @b)
    delete trip_round_match_path(@trip, @round, match)
    assert_empty @round.matches.reload
    assert @a.reload.update(team: teams.last)
  end

  test "invalid hole entry rolls back every player in the submission" do
    @round.update!(course_confirmed: true)
    hole = @round.holes.first
    patch trip_round_hole_hole_scores_path(@trip, @round, hole), params: { strokes: { @a.id.to_s => 4, @b.id.to_s => 0 } }
    assert_empty hole.hole_scores.reload
  end

  test "duplicate stroke indexes leave the original course card unchanged" do
    original_ids = @round.holes.pluck(:id)
    card = @round.holes.to_h { |hole| [ hole.id.to_s, { par: 4, stroke_index: 1 } ] }
    patch trip_round_course_card_path(@trip, @round), params: { holes: card }
    assert_not @round.reload.course_confirmed?
    assert_equal original_ids.sort, @round.holes.pluck(:id).sort
  end
end
