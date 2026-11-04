class Leaderboard
  Entry = Data.define(:player, :rounds_played, :gross, :net, :complete)

  def self.for(trip)
    round_count = trip.rounds.count
    trip.players.includes(:scores).map do |player|
      scores = player.scores.to_a
      Entry.new(player: player, rounds_played: scores.size,
        gross: scores.sum(&:gross), net: scores.sum(&:net),
        complete: round_count.positive? && scores.size == round_count)
    end.sort_by { |entry| [ entry.complete ? 0 : 1, -entry.rounds_played, entry.net, entry.player.name ] }
  end
end
