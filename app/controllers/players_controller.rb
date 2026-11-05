class PlayersController < ApplicationController
  def destroy
    trip = find_trip!(manage: true)
    player = trip.players.find(params[:id])
    name = player.name
    trip.with_lock { player.destroy! }
    redirect_to trip_path(trip, view: "manage", anchor: "manage-players"),
      notice: "#{name} removed. Their scores and match pairings were deleted.", status: :see_other
  end

  def update
    trip = find_trip!(manage: true)
    player = trip.players.find(params[:id])
    if player.update(params.require(:player).permit(:team_id))
      redirect_to trip, notice: "Team assignment saved."
    else
      redirect_to trip, alert: player.errors.full_messages.to_sentence
    end
  end

  def create
    trip = find_trip!(manage: true)
    player = trip.players.build(params.require(:player).permit(:name, :playing_handicap, :team_id))
    if player.save
      redirect_to trip, notice: "#{player.name} is on the trip."
    else
      redirect_to trip, alert: player.errors.full_messages.to_sentence
    end
  end
end
