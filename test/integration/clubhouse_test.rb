require "test_helper"

class ClubhouseTest < ActionDispatch::IntegrationTest
  setup do
    @old_password = ENV["ORGANIZER_PASSWORD"]
    ENV["ORGANIZER_PASSWORD"] = "local-test-only"
    post session_path, params: { password: ENV["ORGANIZER_PASSWORD"] }

    @trip = Trip.create!(name: "Rivalry Week", destination: "Pinehurst",
      starts_on: "2027-05-01", ends_on: "2027-05-04")
    red, blue = %w[Red Blue].map { |name| @trip.teams.create!(name: name) }
    @joe = @trip.players.create!(name: "Joe", team: red, playing_handicap: 0)
    @matt = @trip.players.create!(name: "Matt", team: blue, playing_handicap: 0)
    @round = @trip.rounds.create!(course: "No. 2", plays_on: @trip.starts_on, scoring_mode: :hole_by_hole)
    @round.update!(course_confirmed: true)
  end

  teardown { ENV["ORGANIZER_PASSWORD"] = @old_password }

  test "clubhouse displays live board, birdie reel and match progress" do
    @round.matches.create!(home_player: @joe, away_player: @matt)
    first_hole = @round.holes.find_by!(number: 1)
    first_hole.hole_scores.create!(player: @joe, strokes: 3)
    first_hole.hole_scores.create!(player: @matt, strokes: 5)

    get trip_clubhouse_path(@trip)
    assert_response :success
    assert_select "turbo-frame#clubhouse_live[src]"

    get trip_live_clubhouse_path(@trip, round_id: @round.id)
    assert_response :success
    assert_select "turbo-frame#clubhouse_live"
    assert_select ".live-score-row", count: 2
    assert_select ".live-match", count: 1
    assert_select ".live-moment", text: /Birdie!/
    assert_select ".live-progress-track[aria-valuenow='6']"
  end

  test "empty trip has a clubhouse onboarding state" do
    empty = Trip.create!(name: "Empty", destination: "Myrtle Beach",
      starts_on: "2027-06-01", ends_on: "2027-06-03")
    get trip_live_clubhouse_path(empty)
    assert_response :success
    assert_select "h2", text: "Make some golf history."
  end

  test "the selected round must belong to this trip" do
    other = Trip.create!(name: "Other", destination: "Bandon",
      starts_on: "2027-07-01", ends_on: "2027-07-03")
    other_round = other.rounds.create!(course: "Other Course", plays_on: other.starts_on)
    get trip_clubhouse_path(@trip, round_id: other_round.id)
    assert_response :not_found
  end
end
