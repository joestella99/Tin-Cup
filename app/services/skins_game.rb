# A side game derived from existing gross hole scores. A skin is awarded only
# when every participating golfer has a score for the hole and one is uniquely low.
# Tied holes carry their pot forward, including across unfinished holes.
class SkinsGame
  HoleResult = Data.define(:number, :par, :status, :winner, :pot, :low_score, :tied_players)
  PlayerResult = Data.define(:player, :skins, :holes_won)
  attr_reader :holes, :leaders, :unclaimed, :players

  def self.for(round)
    new(round)
  end

  def initialize(round)
    raise ArgumentError, "Skins requires a hole-by-hole round" unless round.hole_by_hole?
    @players = round.trip.players.order(:name).to_a
    scores = round.hole_scores.includes(:player, :hole).group_by(&:hole_id)
    pot = 0
    tally = Hash.new(0)
    won = Hash.new(0)
    @holes = round.holes.order(:number).map do |hole|
      entries = scores.fetch(hole.id, [])
      if @players.size < 2 || entries.size != @players.size
        HoleResult.new(number: hole.number, par: hole.par, status: :pending, winner: nil,
          pot: pot, low_score: nil, tied_players: [])
      else
        pot += 1
        lowest = entries.map(&:strokes).min
        tied = entries.select { |score| score.strokes == lowest }.map(&:player)
        if tied.one?
          winner = tied.first
          tally[winner.id] += pot
          won[winner.id] += 1
          result = HoleResult.new(number: hole.number, par: hole.par, status: :won,
            winner: winner, pot: pot, low_score: lowest, tied_players: [])
          pot = 0
          result
        else
          HoleResult.new(number: hole.number, par: hole.par, status: :carry,
            winner: nil, pot: pot, low_score: lowest, tied_players: tied)
        end
      end
    end
    @unclaimed = pot
    @leaders = @players.map do |player|
      PlayerResult.new(player: player, skins: tally[player.id], holes_won: won[player.id])
    end.sort_by { |result| [ -result.skins, result.player.name ] }
  end
end
