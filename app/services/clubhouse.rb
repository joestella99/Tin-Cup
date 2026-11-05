# Read-only presentation of a trip's latest scoring activity.
# No stored projections: a corrected score is reflected on the next refresh.
class Clubhouse
  Standing = Data.define(:player, :holes, :gross, :net, :to_par, :net_to_par, :complete)
  Moment = Data.define(:player, :round, :hole, :strokes, :label, :kind, :at)
  Matchup = Data.define(:match, :result)

  attr_reader :trip, :rounds, :round, :standings, :moments, :matchups, :cup_standings,
    :cards_entered, :last_update

  def self.for(trip, round: nil)
    new(trip, round: round)
  end

  def initialize(trip, round: nil)
    @trip = trip
    @rounds = trip.rounds.includes(:scores, :matches, holes: { hole_scores: :player }).order(:plays_on, :id).to_a
    @players = trip.players.includes(:team).order(:name).to_a
    @round = round && @rounds.find { |item| item.id == round.id }
    @round ||= focus_round
    @cup_standings = CupStandings.for(trip)
    @standings = build_standings
    @matchups = @round ? @round.matches.map { |match| Matchup.new(match: match, result: MatchResult.for(match)) } : []
    @moments = build_moments
    @cards_entered = @rounds.sum { |item| scores_for(item).size }
    @last_update = @rounds.flat_map { |item| scores_for(item).map(&:updated_at) }.compact.max
  end

  def players_count
    @players.size
  end

  def live_matches_count
    matchups.count { |matchup| matchup.result.status == :live }
  end

  def round_progress
    return 0 if @players.empty? || !round

    (standings.sum(&:holes).fdiv(@players.size * 18) * 100).round
  end

  private

  def scores_for(item)
    item.total? ? item.scores.to_a : item.holes.flat_map { |hole| hole.hole_scores.to_a }
  end

  def focus_round
    scored = @rounds.select { |item| scores_for(item).any? }
    scored.max_by { |item| scores_for(item).map(&:updated_at).compact.max || Time.at(0) } ||
      @rounds.find { |item| item.plays_on >= Date.current } || @rounds.last
  end

  def build_standings
    return [] unless round

    if round.total?
      by_player = round.scores.index_by(&:player_id)
      @players.map do |player|
        score = by_player[player.id]
        Standing.new(player: player, holes: score ? 18 : 0, gross: score&.gross,
          net: score ? score.gross - player.playing_handicap : nil,
          to_par: nil, net_to_par: nil, complete: score.present?)
      end.sort_by { |standing| [ standing.net.nil? ? 1 : 0, standing.net || 0, standing.player.name ] }
    else
      by_player = round.holes.flat_map do |hole|
        hole.hole_scores.map { |score| [ score.player_id, hole, score ] }
      end.group_by(&:first)

      @players.map do |player|
        entries = by_player.fetch(player.id, [])
        holes = entries.size
        gross = entries.sum { |_, _, score| score.strokes }
        par = entries.sum { |_, hole, _| hole.par }
        net = entries.sum do |_, hole, score|
          score.strokes - HandicapStrokes.for(player.playing_handicap, hole.stroke_index)
        end
        Standing.new(player: player, holes: holes, gross: holes.positive? ? gross : nil,
          net: holes.positive? ? net : nil, to_par: holes.positive? ? gross - par : nil,
          net_to_par: holes.positive? ? net - par : nil, complete: holes == 18)
      end.sort_by do |standing|
        [ standing.net_to_par.nil? ? 1 : 0, standing.net_to_par || 0, -standing.holes, standing.player.name ]
      end
    end
  end

  def build_moments
    @rounds.flat_map do |event_round|
      next [] unless event_round.hole_by_hole? && event_round.course_confirmed?

      event_round.holes.flat_map do |hole|
        hole.hole_scores.filter_map do |score|
          difference = score.strokes - hole.par
          kind, label =
            if score.strokes == 1
              [ :ace, "Hole-in-one" ]
            elsif difference <= -3
              [ :albatross, "Albatross" ]
            elsif difference == -2
              [ :eagle, "Eagle" ]
            elsif difference == -1
              [ :birdie, "Birdie" ]
            end
          next unless kind

          Moment.new(player: score.player, round: event_round, hole: hole,
            strokes: score.strokes, label: label, kind: kind, at: score.updated_at)
        end
      end
    end.sort_by { |moment| [ moment.at, moment.hole.number ] }.reverse.first(10)
  end
end
