require "test_helper"
class CompetitionTest < ActiveSupport::TestCase
  test "net score subtracts strokes received, including plus handicaps" do
    trip = build_trip
    round = trip.rounds.create!(course: "Course", plays_on: trip.starts_on)
    player = trip.players.create!(name: "Joe", playing_handicap: 12)
    assert_equal 73, round.scores.create!(player: player, gross: 85).net
    plus = trip.players.create!(name: "Pro", playing_handicap: -2)
    assert_equal 72, round.scores.create!(player: plus, gross: 70).net
  end
  test "score cannot cross trips or repeat a player in a round" do
    trip = build_trip
    round = trip.rounds.create!(course: "Course", plays_on: trip.starts_on)
    player = trip.players.create!(name: "Joe", playing_handicap: 12)
    round.scores.create!(player: player, gross: 85)
    assert_not round.scores.build(player: player, gross: 90).valid?
    outsider = build_trip(name: "Other").players.create!(name: "Matt", playing_handicap: 0)
    assert_not round.scores.build(player: outsider, gross: 80).valid?
  end
  test "incomplete players cannot lead completed players with more rounds" do
    trip = build_trip
    rounds = 2.times.map { |i| trip.rounds.create!(course: "Course #{i}", plays_on: trip.starts_on) }
    full = trip.players.create!(name: "Full", playing_handicap: 0)
    partial = trip.players.create!(name: "Partial", playing_handicap: 0)
    rounds.each { |r| r.scores.create!(player: full, gross: 90) }
    rounds.first.scores.create!(player: partial, gross: 70)
    entries = Leaderboard.for(trip)
    assert_equal [ full, partial ], entries.map(&:player)
    assert entries.first.complete
    assert_not entries.last.complete
  end
  test "dates and handicap changes protect competition integrity" do
    trip = build_trip
    assert_not trip.rounds.build(course: "Outside", plays_on: trip.ends_on + 1).valid?
    player = trip.players.create!(name: "Joe", playing_handicap: 12)
    round = trip.rounds.create!(course: "Course", plays_on: trip.starts_on)
    round.scores.create!(player: player, gross: 80)
    assert_not player.update(playing_handicap: 20)
    assert_not round.scores.build(player: player, gross: 0).valid?
  end
end
