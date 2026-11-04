class TripsController < ApplicationController
  def index
    @trips = accessible_trips.order(starts_on: :desc)
  end

  def new
    @trip = Trip.new
  end

  def create
    @trip = Trip.new(params.require(:trip).permit(:name, :destination, :starts_on, :ends_on))
    Trip.transaction do
      @trip.save!
      @trip.memberships.create!(user: current_user, role: :owner) if current_user
    end
    redirect_to @trip, notice: "Trip created. Time to assemble the group."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def show
    @trip = find_trip!
    @can_manage = organizer_for?(@trip)
    @active_invitation = @trip.invitations.active.order(created_at: :desc).first if @can_manage
    @entries = Leaderboard.for(@trip)
    @cup_entries = CupStandings.for(@trip)
    @teams = @trip.teams.order(:name)
    @rounds = @trip.rounds.order(:plays_on, :id)
  end
end
