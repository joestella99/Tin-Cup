require "test_helper"

class ItineraryTest < ActionDispatch::IntegrationTest
  test "only the owner can reschedule a scored round within the trip dates" do
    trip = Trip.create!(name: "Cup", destination: "Pinehurst", starts_on: "2027-05-01", ends_on: "2027-05-05")
    owner, scorer = %w[owner scorer].map do |role|
      user = User.create!(name: role, email_address: "#{role}@example.test", password: "test-password-long", password_confirmation: "test-password-long")
      trip.memberships.create!(user: user, role: role)
      user
    end
    round = trip.rounds.create!(course: "No. 2", plays_on: "2027-05-02")
    player = trip.players.create!(name: "Player", playing_handicap: 10)
    score = round.scores.create!(player: player, gross: 84)

    post session_path, params: { email_address: scorer.email_address, password: "test-password-long" }
    patch trip_round_path(trip, round), params: { round: { plays_on: "2027-05-03" } }
    assert_response :not_found

    post session_path, params: { email_address: owner.email_address, password: "test-password-long" }
    patch trip_path(trip), params: { trip: { starts_on: "2027-05-03" } }
    assert_response :unprocessable_entity
    assert_equal Date.new(2027, 5, 1), trip.reload.starts_on

    patch trip_round_path(trip, round), params: { round: { plays_on: "2027-05-06" } }
    assert_response :unprocessable_entity
    patch trip_round_path(trip, round), params: { round: { plays_on: "2027-05-03", scoring_mode: "hole_by_hole" } }
    assert_response :see_other
    assert_equal Date.new(2027, 5, 3), round.reload.plays_on
    assert round.total?
    assert_equal 84, score.reload.gross

    patch trip_path(trip), params: { trip: { starts_on: "2027-05-03" } }
    assert_response :see_other
    get trip_path(trip)
    assert_response :success
    assert_select "time[datetime='2027-05-03']"
  end
end
