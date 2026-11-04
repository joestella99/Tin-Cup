class TeamsController < ApplicationController
  def create
    trip = Trip.find(params[:trip_id])
    team = trip.teams.build(params.require(:team).permit(:name))
    if team.save
      redirect_to trip, notice: "#{team.name} is in the cup."
    else
      redirect_to trip, alert: team.errors.full_messages.to_sentence
    end
  end
end
