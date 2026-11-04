class TripsController < ApplicationController
  def index
    @trips = Trip.order(starts_on: :desc)
  end

  def new
    @trip = Trip.new
  end

  def create
    @trip = Trip.new(params.require(:trip).permit(:name, :destination, :starts_on, :ends_on))
    if @trip.save
      redirect_to @trip, notice: "Trip created. Time to assemble the group."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @trip = Trip.find(params[:id])
    @entries = Leaderboard.for(@trip)
    @rounds = @trip.rounds.order(:plays_on, :id)
  end
end
