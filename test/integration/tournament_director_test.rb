require "test_helper"

class TournamentDirectorTest < ActionDispatch::IntegrationTest
  setup do
    @old_password = ENV["ORGANIZER_PASSWORD"]
    ENV["ORGANIZER_PASSWORD"] = "local-test-only"
    post session_path, params: { password: ENV["ORGANIZER_PASSWORD"] }
    @trip = build_trip
    red, blue = %w[Red Blue].map { |name| @trip.teams.create!(name: name) }
    @a = @trip.players.create!(name: "A", team: red)
    @b = @trip.players.create!(name: "B", team: blue)
    @round = @trip.rounds.create!(course: "Course", plays_on: @trip.starts_on, scoring_mode: :hole_by_hole)
    @round.update!(course_confirmed: true)
  end
  teardown { ENV["ORGANIZER_PASSWORD"] = @old_password }

  test "organizer previews and confirms pairings and members see skins" do
    get trip_round_pairing_suggestions_path(@trip, @round)
    assert_response :success
    assert_select ".pairing-preview article", count: 1
    post trip_round_pairing_suggestions_path(@trip, @round)
    assert_redirected_to trip_round_path(@trip, @round)
    assert_equal 1, @round.matches.count
    get trip_round_skins_game_path(@trip, @round)
    assert_response :success
    assert_select ".skins-hole", count: 18
  end

  test "no pairings may be created after a score has been entered" do
    @round.holes.first.hole_scores.create!(player: @a, strokes: 4)
    post trip_round_pairing_suggestions_path(@trip, @round)
    assert_equal 0, @round.matches.count
  end
end
