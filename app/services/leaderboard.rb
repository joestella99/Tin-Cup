class Leaderboard
  Entry = Data.define(:player, :rounds_played, :gross, :net, :complete)

  def self.for(trip)
    rounds = trip.rounds.to_a
    results = rounds.map { |round| RoundResults.for(round) }
    trip.players.map do |player|
      completed = results.filter_map { |result| result[player.id] if result[player.id]&.complete }
      Entry.new(player: player, rounds_played: completed.size,
        gross: completed.sum(&:gross), net: completed.sum(&:net),
        complete: rounds.any? && completed.size == rounds.size)
    end.sort_by { |entry| [ entry.complete ? 0 : 1, -entry.rounds_played, entry.net, entry.player.name ] }
  end
end
