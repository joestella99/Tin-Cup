require "test_helper"

class TripCupTest < ActiveSupport::TestCase
  setup do
    @trip = build_trip
    @teams = %w[Sandbaggers Mulligans Shankers].map { |name| @trip.teams.create!(name: name) }
    @home = @trip.players.create!(name: "Joe", team: @teams[0], playing_handicap: 12)
    @away = @trip.players.create!(name: "Matt", team: @teams[1], playing_handicap: 0)
    @round = @trip.rounds.create!(course: "Trip Course", plays_on: @trip.starts_on, scoring_mode: :hole_by_hole)
    @round.update!(course_confirmed: true)
  end

  def score_holes(numbers, home: 4, away: 4)
    @round.holes.where(number: numbers).each do |hole|
      hole.hole_scores.create!(player: @home, strokes: home)
      hole.hole_scores.create!(player: @away, strokes: away)
    end
  end

  test "unconfirmed course card cannot accept hole scores" do
    @round.update!(course_confirmed: false)
    assert_not @round.holes.first.hole_scores.build(player: @home, strokes: 4).valid?
  end

  test "any number of teams share one table without a fixed team count" do
    9.times { |i| @trip.teams.create!(name: "Team #{i}") }
    assert_equal 12, CupStandings.for(@trip).size
    assert CupStandings.for(@trip).all? { |entry| entry.points.zero? }
  end

  test "stroke allocation handles multiple strokes and plus handicaps" do
    assert_equal 2, HandicapStrokes.for(20, 2)
    assert_equal 1, HandicapStrokes.for(20, 3)
    assert_equal(-1, HandicapStrokes.for(-2, 18))
    assert_equal 0, HandicapStrokes.for(-2, 1)
    assert_equal 20, (1..18).sum { |index| HandicapStrokes.for(20, index) }
    assert_equal(-2, (1..18).sum { |index| HandicapStrokes.for(-2, index) })
  end

  test "match strokes use the handicap difference and final points count once" do
    match = @round.matches.create!(home_player: @home, away_player: @away)
    score_holes(1..10)
    result = MatchResult.for(match)
    assert_equal :final, result.status
    assert_equal @home, result.leader
    assert_equal 10, result.through
    assert_equal 1.0, result.home_points
    standings = CupStandings.for(@trip)
    assert_equal 1.0, standings.find { |entry| entry.team == @teams[0] }.points
    assert_equal 0, standings.find { |entry| entry.team == @teams[2] }.played
    assert_not Leaderboard.for(@trip).find { |entry| entry.player == @home }.complete
  end

  test "an all-square match awards half a point to both teams after eighteen" do
    @home.update!(playing_handicap: 0)
    match = @round.matches.create!(home_player: @home, away_player: @away)
    score_holes(1..18)
    result = MatchResult.for(match)
    assert_equal :final, result.status
    assert_nil result.leader
    assert_equal 0.5, result.home_points
    assert_equal 0.5, result.away_points
    assert_equal 72, Leaderboard.for(@trip).find { |entry| entry.player == @home }.net
    assert_equal [ 0.5, 0.5, 0.0 ], CupStandings.for(@trip).map(&:points)
  end

  test "missing earlier holes cannot imply a lead or award points" do
    match = @round.matches.create!(home_player: @home, away_player: @away)
    score_holes(2..18)
    result = MatchResult.for(match)
    assert_equal :scheduled, result.status
    assert_equal 0, result.through
    assert_equal 0, CupStandings.for(@trip).sum(&:points)
  end

  test "invalid pairings and changes cannot alter team history" do
    assert_not @round.matches.build(home_player: @home, away_player: @home).valid?
    teammate = @trip.players.create!(name: "Dan", team: @teams[0], playing_handicap: 0)
    assert_not @round.matches.build(home_player: @home, away_player: teammate).valid?
    @round.matches.create!(home_player: @home, away_player: @away)
    outsider = @trip.players.create!(name: "Chris", team: @teams[2], playing_handicap: 0)
    assert_not @round.matches.build(home_player: @home, away_player: outsider).valid?
    assert_not @home.update(team: @teams[2])
    @home.reload
    assert_not @home.update(playing_handicap: 20)
  end

  test "completed hole rounds and legacy total rounds both contribute to net standings" do
    score_holes(1..18)
    legacy = @trip.rounds.create!(course: "Legacy", plays_on: @trip.starts_on)
    legacy.scores.create!(player: @home, gross: 84)
    entry = Leaderboard.for(@trip).find { |e| e.player == @home }
    assert_equal 2, entry.rounds_played
    assert_equal 132, entry.net
    assert entry.complete
    assert_not @round.scores.build(player: @home, gross: 72).valid?
    alien = build_trip(name: "Other").players.create!(name: "Alien", playing_handicap: 0)
    assert_not @round.holes.first.hole_scores.build(player: alien, strokes: 4).valid?
  end
end
