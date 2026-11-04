class ScorecardsController < ApplicationController
  def update
    trip = Trip.find(params[:trip_id])
    round = trip.rounds.find(params[:round_id])
    return redirect_to trip_round_path(trip, round), alert: "Use the hole-by-hole scorecard for this round." if round.hole_by_hole?
    submitted = params.fetch(:scores, ActionController::Parameters.new).permit(*trip.players.pluck(:id).map(&:to_s)).to_h
    Score.transaction do
      submitted.each do |player_id, gross|
        player = trip.players.find(player_id)
        score = round.scores.find_or_initialize_by(player: player)
        if gross.blank?
          score.destroy! if score.persisted?
        else
          score.update!(gross: gross)
        end
      end
    end
    redirect_to trip_round_path(trip, round), notice: "Scores saved. Trip standings are updated."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to trip_round_path(trip, round), alert: error.record.errors.full_messages.to_sentence
  end
end
