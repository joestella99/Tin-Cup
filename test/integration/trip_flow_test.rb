require "test_helper"
class TripFlowTest < ActionDispatch::IntegrationTest
  setup do
    @previous_password = ENV["ORGANIZER_PASSWORD"]
    ENV["ORGANIZER_PASSWORD"] = "test-password-for-tin-cup"
  end
  teardown { ENV["ORGANIZER_PASSWORD"] = @previous_password }

  test "organizer creates a trip, adds players, records and clears scores" do
    get root_path
    assert_redirected_to new_session_path
    get new_session_path
    assert_response :success
    post session_path, params: { password: "incorrect" }
    assert_response :unprocessable_entity
    post session_path, params: { password: ENV["ORGANIZER_PASSWORD"] }
    get new_trip_path
    assert_response :success
    post trips_path, params: { trip: { name: "Buddy Cup", destination: "Pinehurst", starts_on: "2027-05-01", ends_on: "2027-05-03" } }
    trip = Trip.last
    post trip_players_path(trip), params: { player: { name: "Joe", playing_handicap: 12 } }
    post trip_rounds_path(trip), params: { round: { course: "Pine Needles", plays_on: "2027-05-01" } }
    round = trip.rounds.first
    player = trip.players.first
    patch trip_round_scorecard_path(trip, round), params: { scores: { player.id.to_s => "85" } }
    assert_equal 73, round.scores.first.net
    get trip_round_path(trip, round)
    assert_response :success
    get trips_path
    assert_response :success
    get trip_path(trip)
    assert_response :success
    assert_select "td.net", text: "73"
    patch trip_round_scorecard_path(trip, round), params: { scores: { player.id.to_s => "" } }
    assert_empty round.scores.reload
  end

  test "one invalid score rolls back the entire scorecard" do
    post session_path, params: { password: ENV["ORGANIZER_PASSWORD"] }
    trip = Trip.create!(name: "Cup", destination: "NC", starts_on: "2027-05-01", ends_on: "2027-05-03")
    a = trip.players.create!(name: "A", playing_handicap: 0)
    b = trip.players.create!(name: "B", playing_handicap: 0)
    round = trip.rounds.create!(course: "Course", plays_on: trip.starts_on)
    patch trip_round_scorecard_path(trip, round), params: { scores: { a.id.to_s => "80", b.id.to_s => "-1" } }
    assert_empty round.scores.reload
  end
end
