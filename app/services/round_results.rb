class RoundResults
  Result = Data.define(:gross, :net, :holes_played, :complete)

  def self.for(round)
    if round.total?
      round.scores.includes(:player).index_with { |score| Result.new(gross: score.gross, net: score.net, holes_played: 18, complete: true) }.transform_keys(&:player_id)
    else
      round.hole_scores.includes(:hole, :player).group_by(&:player_id).transform_values do |scores|
        gross = scores.sum(&:strokes)
        net = scores.sum { |s| s.strokes - HandicapStrokes.for(s.player.playing_handicap, s.hole.stroke_index) }
        Result.new(gross: gross, net: net, holes_played: scores.size, complete: scores.size == 18)
      end
    end
  end
end
