class HoleScoresController < ApplicationController
  def update
    trip = Trip.find(params[:trip_id])
    round = trip.rounds.find(params[:round_id])
    hole = round.holes.find(params[:hole_id])
    submitted = params.fetch(:strokes, ActionController::Parameters.new).permit(*trip.players.pluck(:id).map(&:to_s)).to_h
    round.with_lock do
      submitted.each do |player_id, strokes|
        player = trip.players.find(player_id)
        score = hole.hole_scores.find_or_initialize_by(player: player)
        if strokes.blank?
          score.destroy! if score.persisted?
        else
          score.update!(strokes: strokes)
        end
      end
    end
    redirect_to trip_round_path(trip, round, hole: hole.number), notice: "Hole #{hole.number} saved. Match standings updated."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to trip_round_path(trip, round, hole: hole.number), alert: error.record.errors.full_messages.to_sentence
  end
end
