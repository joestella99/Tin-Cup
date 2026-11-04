class RoundsController < ApplicationController
  def create
    trip = Trip.find(params[:trip_id])
    round = trip.rounds.build(params.require(:round).permit(:course, :plays_on))
    if round.save
      redirect_to trip, notice: "Round added to the itinerary."
    else
      redirect_to trip, alert: round.errors.full_messages.to_sentence
    end
  end

  def show
    @trip = Trip.find(params[:trip_id])
    @round = @trip.rounds.find(params[:id])
    @players = @trip.players.order(:name)
    @scores = @round.scores.index_by(&:player_id)
  end
end
