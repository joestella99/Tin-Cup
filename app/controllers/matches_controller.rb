class MatchesController < ApplicationController
  def destroy
    trip = Trip.find(params[:trip_id])
    round = trip.rounds.find(params[:round_id])
    match = round.matches.find(params[:id])
    round.with_lock do
      if round.hole_scores.where(player_id: [ match.home_player_id, match.away_player_id ]).exists?
        return redirect_to trip_round_path(trip, round), alert: "Pairings lock after either player begins scoring."
      end
      match.destroy!
    end
    redirect_to trip_round_path(trip, round), notice: "Pairing removed. You can reassign these players."
  end

  def create
    trip = Trip.find(params[:trip_id])
    round = trip.rounds.find(params[:round_id])
    match = round.matches.build(params.require(:match).permit(:home_player_id, :away_player_id))
    round.with_lock { match.save! }
    redirect_to trip_round_path(trip, round), notice: "Singles match added. One point is on the line."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to trip_round_path(trip, round), alert: error.record.errors.full_messages.to_sentence
  end
end
