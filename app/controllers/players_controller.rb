class PlayersController < ApplicationController
  def update
    trip = Trip.find(params[:trip_id])
    player = trip.players.find(params[:id])
    if player.update(params.require(:player).permit(:team_id))
      redirect_to trip, notice: "Team assignment saved."
    else
      redirect_to trip, alert: player.errors.full_messages.to_sentence
    end
  end

  def create
    trip = Trip.find(params[:trip_id])
    player = trip.players.build(params.require(:player).permit(:name, :playing_handicap, :team_id))
    if player.save
      redirect_to trip, notice: "#{player.name} is on the trip."
    else
      redirect_to trip, alert: player.errors.full_messages.to_sentence
    end
  end
end
