require "test_helper"

class TripExperienceTest < ActionDispatch::IntegrationTest
  setup do
    @password = ENV["ORGANIZER_PASSWORD"]
    ENV["ORGANIZER_PASSWORD"] = "test-only-captain-password"
    post session_path, params: { password: ENV["ORGANIZER_PASSWORD"] }
    @trip = build_trip(name: "The Annual Cup")
    @players = 5.times.map { |index| @trip.players.create!(name: "Golfer #{index + 1}", playing_handicap: index) }
    @round = @trip.rounds.create!(course: "Pinehurst", plays_on: @trip.starts_on, scoring_mode: :hole_by_hole)
    @round.update!(course_confirmed: true)
  end

  teardown { ENV["ORGANIZER_PASSWORD"] = @password }

  test "home makes the next scorecard obvious and separates captain tools" do
    get trip_path(@trip)
    assert_response :success
    assert_select ".hq-tabs .active", text: "Home"
    assert_select ".hq-next-card a", text: /scorecard/
    assert_select "#schedule-round", count: 0
    get trip_path(@trip, view: "manage")
    assert_response :success
    assert_select "#schedule-round form", count: 1
    assert_select "#add-player form", count: 1
    assert_select ".hq-task", minimum: 4
    get trip_path(@trip, view: "play")
    assert_response :success
    assert_select ".hq-round-card", count: 1
    get trip_path(@trip, view: "standings")
    assert_response :success
    assert_select ".hq-standings", count: 1
  end

  test "mobile focus scoring updates only one golfer and stays focused across holes" do
    first = @round.holes.find_by!(number: 1)
    first.hole_scores.create!(player: @players.second, strokes: 5)
    get trip_round_path(@trip, @round, hole: 1, player_id: @players.first.id)
    assert_response :success
    assert_select ".score-stepper", count: 1
    assert_select ".score-focus-chip.selected", text: @players.first.name
    patch trip_round_hole_hole_scores_path(@trip, @round, first),
      params: { player_id: @players.first.id, strokes: { @players.first.id.to_s => 4 }, next_hole: "1" }
    assert_redirected_to trip_round_path(@trip, @round, hole: 2, player_id: @players.first.id.to_s)
    assert_equal 5, first.hole_scores.find_by!(player: @players.second).strokes
    assert_equal 4, first.hole_scores.find_by!(player: @players.first).strokes
    get trip_round_path(@trip, @round, hole: 2, player_id: @players.first.id)
    assert_select ".score-stepper", count: 1
    get trip_round_path(@trip, @round, hole: 2, player_id: "all")
    assert_select ".score-stepper", count: 5
  end

  test "a real match becomes the captain's rivalry briefing" do
    red = @trip.teams.create!(name: "Red")
    blue = @trip.teams.create!(name: "Blue")
    @players.first.update!(team: red)
    @players.second.update!(team: blue)
    @round.matches.create!(home_player: @players.first, away_player: @players.second)
    first = @round.holes.find_by!(number: 1)
    first.hole_scores.create!(player: @players.first, strokes: 3)
    first.hole_scores.create!(player: @players.second, strokes: 5)
    get trip_path(@trip)
    assert_response :success
    assert_select ".hq-story-card", text: /Golfer 1/
    assert_select ".hq-story-card", text: /LIVE/
  end
end
