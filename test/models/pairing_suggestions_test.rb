require "test_helper"

class PairingSuggestionsTest < ActiveSupport::TestCase
  test "suggestions only cross teams and prefer previously unseen opponents" do
    trip = build_trip
    red, blue, green = %w[Red Blue Green].map { |name| trip.teams.create!(name: name) }
    a = trip.players.create!(name: "A", team: red)
    b = trip.players.create!(name: "B", team: blue)
    c = trip.players.create!(name: "C", team: green)
    first = trip.rounds.create!(course: "First", plays_on: trip.starts_on, scoring_mode: :hole_by_hole)
    first.update!(course_confirmed: true)
    first.matches.create!(home_player: a, away_player: b)
    second = trip.rounds.create!(course: "Second", plays_on: trip.starts_on + 1, scoring_mode: :hole_by_hole)
    second.update!(course_confirmed: true)
    suggestions = PairingSuggestions.for(second)
    assert_equal 1, suggestions.pairs.size
    assert_equal 0, suggestions.pairs.first.prior_meetings
    assert_not_equal suggestions.pairs.first.home.team_id, suggestions.pairs.first.away.team_id
    assert_equal 1, suggestions.unpaired.size
    assert_includes [a, b, c], suggestions.unpaired.first
  end
end
