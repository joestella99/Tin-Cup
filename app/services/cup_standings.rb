class CupStandings
  Entry = Data.define(:team, :points, :played, :won, :tied)

  def self.for(trip)
    totals = trip.teams.to_h { |team| [ team.id, { team: team, points: 0.0, played: 0, won: 0, tied: 0 } ] }
    Match.joins(:round).where(rounds: { trip_id: trip.id }).includes(:home_player, :away_player, :round).each do |match|
      result = MatchResult.for(match)
      next unless result.status == :final
      [ [ match.home_player.team_id, result.home_points ], [ match.away_player.team_id, result.away_points ] ].each do |team_id, points|
        total = totals.fetch(team_id)
        total[:points] += points
        total[:played] += 1
        total[:won] += 1 if points == 1.0
        total[:tied] += 1 if points == 0.5
      end
    end
    totals.values.map { |values| Entry.new(**values) }.sort_by { |entry| [ -entry.points, entry.team.name ] }
  end
end
