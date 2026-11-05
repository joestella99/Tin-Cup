# Suggest fair singles pairings for the next round without changing any records.
# Prior opponents are penalized, and teams with fewer scheduled matches are favored.
class PairingSuggestions
  Pair = Data.define(:home, :away, :prior_meetings)
  attr_reader :pairs, :unpaired

  def self.for(round)
    new(round)
  end

  def initialize(round)
    players = round.trip.players.includes(:team).where.not(team_id: nil).order(:name).to_a
    taken = round.matches.pluck(:home_player_id, :away_player_id).flatten
    available = players.reject { |player| taken.include?(player.id) }
    previous = Match.joins(:round).where(rounds: { trip_id: round.trip_id })
      .where.not(round_id: round.id).pluck(:home_player_id, :away_player_id)
    counts = Hash.new(0)
    previous.each { |a, b| counts[[a, b].sort] += 1 }
    team_matches = Hash.new(0)
    round.matches.includes(:home_player, :away_player).each do |match|
      team_matches[match.home_player.team_id] += 1
      team_matches[match.away_player.team_id] += 1
    end
    @pairs = []
    while available.size >= 2
      options = available.combination(2).reject { |a, b| a.team_id == b.team_id }
      break if options.empty?
      a, b = options.min_by do |first, second|
        [ counts[[first.id, second.id].sort],
          team_matches[first.team_id] + team_matches[second.team_id],
          [first.name, second.name].sort ]
      end
      @pairs << Pair.new(home: a, away: b, prior_meetings: counts[[a.id, b.id].sort])
      available.delete(a)
      available.delete(b)
      team_matches[a.team_id] += 1
      team_matches[b.team_id] += 1
    end
    @unpaired = available
  end
end
