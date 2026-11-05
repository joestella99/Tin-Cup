class PairingSuggestionsController < ApplicationController
  before_action :load_round

  def show
    @suggestions = PairingSuggestions.for(@round)
  end

  def create
    suggestions = PairingSuggestions.for(@round)
    raise ActiveRecord::RecordInvalid.new(@round) if suggestions.pairs.empty?

    @round.with_lock do
      raise ActiveRecord::RecordInvalid.new(@round) if @round.hole_scores.exists?
      suggestions = PairingSuggestions.for(@round)
      suggestions.pairs.each do |pair|
        @round.matches.create!(home_player: pair.home, away_player: pair.away)
      end
    end
    redirect_to trip_round_path(@trip, @round),
      notice: "#{suggestions.pairs.size} singles #{'match'.pluralize(suggestions.pairs.size)} paired. Let the rivalry begin."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to trip_round_pairing_suggestions_path(@trip, @round),
      alert: error.record.errors.full_messages.presence&.to_sentence || "Pairings could not be created. No changes were saved."
  end

  private

  def load_round
    @trip = find_trip!(manage: true)
    @round = @trip.rounds.find(params[:round_id])
    raise ActiveRecord::RecordNotFound unless @round.hole_by_hole? && @round.course_confirmed?
  end
end
