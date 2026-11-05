# Read-only, player-specific derived facts for the thumb-first golf cart view.
# Incomplete holes never contribute to this player's provisional net to par.
class CartScorecard
  Choice = Data.define(:strokes, :label)
  attr_reader :round, :player, :holes, :scores

  def initialize(round, player)
    @round = round
    @player = player
    @holes = round.holes.order(:number).to_a
    @scores = round.hole_scores.where(player_id: player.id).includes(:hole).index_by { |entry| entry.hole.number }
  end

  def completed_holes = scores.size
  def completed? = holes.size == 18 && completed_holes == 18
  def next_hole = holes.find { |hole| !scores.key?(hole.number) } || holes.last
  def score_for(hole) = scores[hole.number]
  def progress = (completed_holes.fdiv(18) * 100).round
  def gross = scores.values.sum(&:strokes)
  def to_par = scores.values.sum { |s| s.strokes - s.hole.par }

  def net_to_par
    scores.values.sum do |s|
      s.strokes - s.hole.par - HandicapStrokes.for(player.playing_handicap, s.hole.stroke_index)
    end
  end

  def display_to_par(value)
    value.positive? ? "+#{value}" : (value.zero? ? "E" : value.to_s)
  end

  def suggestions(hole)
    ((hole.par - 2)..(hole.par + 4)).select { |score| score.between?(1, 30) }.map do |score|
      Choice.new(strokes: score, label: label_for(score, hole.par))
    end
  end

  def label_for(score, par)
    return "ACE" if score == 1
    difference = score - par
    { -3 => "ALBATROSS", -2 => "EAGLE", -1 => "BIRDIE", 0 => "PAR",
      1 => "BOGEY", 2 => "DOUBLE", 3 => "TRIPLE" }.fetch(difference) do
      difference.positive? ? "+#{difference}" : difference.to_s
    end
  end
end
