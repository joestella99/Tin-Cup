class PlayersController < ApplicationController
  def create
    trip = Trip.find(params[:trip_id])
    player = trip.players.build(params.require(:player).permit(:name, :playing_handicap))
    if player.save
      redirect_to trip, notice: "#{player.name} is on the trip."
    else
      redirect_to trip, alert: player.errors.full_messages.to_sentence
    end
  end
end
