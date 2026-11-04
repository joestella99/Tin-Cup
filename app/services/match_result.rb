class MatchResult
  Result = Data.define(:status, :leader, :through, :margin, :home_points, :away_points)

  def self.for(match)
    scores = match.round.hole_scores.where(player_id: [ match.home_player_id, match.away_player_id ]).index_by { |s| [ s.hole_id, s.player_id ] }
    advantage = 0
    through = 0
    difference = match.home_player.playing_handicap - match.away_player.playing_handicap
    match.round.holes.order(:number).each do |hole|
      home = scores[[ hole.id, match.home_player_id ]]
      away = scores[[ hole.id, match.away_player_id ]]
      break unless home && away
      home_net = home.strokes - HandicapStrokes.for([ difference, 0 ].max, hole.stroke_index)
      away_net = away.strokes - HandicapStrokes.for([ -difference, 0 ].max, hole.stroke_index)
      advantage += away_net <=> home_net
      through += 1
      break if advantage.abs > 18 - through
    end
    finished = through == 18 || advantage.abs > 18 - through
    leader = advantage.positive? ? match.home_player : (advantage.negative? ? match.away_player : nil)
    home_points = finished ? (advantage.positive? ? 1.0 : (advantage.zero? ? 0.5 : 0.0)) : 0.0
    away_points = finished ? 1.0 - home_points : 0.0
    Result.new(status: finished ? :final : (through.zero? ? :scheduled : :live), leader: leader,
      through: through, margin: advantage.abs, home_points: home_points, away_points: away_points)
  end
end
