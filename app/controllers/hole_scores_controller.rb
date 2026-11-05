class HoleScoresController < ApplicationController
  def update
    trip = find_trip!
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
    destination = params[:next_hole] == "1" && hole.number < 18 ? hole.number + 1 : hole.number
    redirect_to trip_round_path(trip, round, hole: destination, player_id: focus_player_id(trip)), notice: "Hole #{hole.number} saved. Match standings updated."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to trip_round_path(trip, round, hole: hole.number, player_id: focus_player_id(trip)), alert: error.record.errors.full_messages.to_sentence
  end

  private

  def focus_player_id(trip)
    return "all" if params[:player_id] == "all"
    params[:player_id] if params[:player_id].present? && trip.players.exists?(id: params[:player_id])
  end
  end
end
