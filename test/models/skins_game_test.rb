require "test_helper"

class SkinsGameTest < ActiveSupport::TestCase
  setup do
    @trip = build_trip
    @a = @trip.players.create!(name: "A")
    @b = @trip.players.create!(name: "B")
    @round = @trip.rounds.create!(course: "Course", plays_on: @trip.starts_on, scoring_mode: :hole_by_hole)
    @round.update!(course_confirmed: true)
  end

  test "ties carry over and next unique low score wins accumulated skins" do
    first, second = @round.holes.order(:number).first(2)
    first.hole_scores.create!(player: @a, strokes: 4)
    first.hole_scores.create!(player: @b, strokes: 4)
    second.hole_scores.create!(player: @a, strokes: 3)
    second.hole_scores.create!(player: @b, strokes: 5)
    game = SkinsGame.for(@round)
    assert_equal :carry, game.holes[0].status
    assert_equal :won, game.holes[1].status
    assert_equal 2, game.holes[1].pot
    assert_equal 2, game.leaders.first.skins
    assert_equal @a, game.leaders.first.player
    assert_equal 0, game.unclaimed
  end

  test "a missing score never awards a skin and corrections recalculate" do
    hole = @round.holes.first
    hole.hole_scores.create!(player: @a, strokes: 3)
    assert_equal :pending, SkinsGame.for(@round).holes.first.status
    other = hole.hole_scores.create!(player: @b, strokes: 4)
    assert_equal :won, SkinsGame.for(@round).holes.first.status
    other.update!(strokes: 3)
    game = SkinsGame.for(@round)
    assert_equal :carry, game.holes.first.status
    assert_equal 1, game.unclaimed
  end
end
