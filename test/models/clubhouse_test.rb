require "test_helper"

class ClubhouseModelTest < ActiveSupport::TestCase
  setup do
    @trip = build_trip
    @joe = @trip.players.create!(name: "Joe", playing_handicap: 0)
    @matt = @trip.players.create!(name: "Matt", playing_handicap: 0)
    @round = @trip.rounds.create!(course: "No. 2", plays_on: @trip.starts_on, scoring_mode: :hole_by_hole)
    @round.update!(course_confirmed: true)
  end

  test "partial scores rank by net to par and corrections replace highlights" do
    hole = @round.holes.find_by!(number: 1)
    score = hole.hole_scores.create!(player: @joe, strokes: 2)
    hole.hole_scores.create!(player: @matt, strokes: 5)

    board = Clubhouse.for(@trip)
    assert_equal @joe, board.standings.first.player
    assert_equal(-2, board.standings.first.net_to_par)
    assert_equal 6, board.round_progress
    assert_equal "Eagle", board.moments.first.label

    score.update!(strokes: 4)
    board = Clubhouse.for(@trip)
    assert_empty board.moments
    assert_equal @joe, board.standings.first.player
    assert_equal 2, board.cards_entered
  end

  test "a legacy total round can be featured without requiring course holes" do
    total = @trip.rounds.create!(course: "Classic", plays_on: @trip.starts_on + 1)
    total.scores.create!(player: @matt, gross: 81)
    board = Clubhouse.for(@trip, round: total)
    assert_equal total, board.round
    assert_equal @matt, board.standings.first.player
    assert_equal 81, board.standings.first.net
    assert_empty board.moments
  end
end
