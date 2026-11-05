class TripsController < ApplicationController
  def index
    @trips = accessible_trips.order(starts_on: :desc)
  end

  def new
    @trip = Trip.new
  end

  def create
    @trip = Trip.new(trip_params)
    Trip.transaction do
      @trip.save!
      @trip.memberships.create!(user: current_user, role: :owner) if current_user
    end
    redirect_to @trip, notice: "Trip created. Time to assemble the group."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
    @trip = find_trip!(manage: true)
  end

  def update
    @trip = find_trip!(manage: true)
    if @trip.with_lock { @trip.update(trip_params) }
      redirect_to @trip, notice: "Trip details updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def delete_confirmation
    @trip = find_trip!(manage: true)
  end

  def destroy
    @trip = find_trip!(manage: true)
    unless ActiveSupport::SecurityUtils.secure_compare(params[:confirmation_name].to_s.strip, @trip.name)
      @deletion_error = "Type the exact trip name to confirm deletion."
      return render :delete_confirmation, status: :unprocessable_entity
    end

    name = @trip.name
    @trip.destroy!
    redirect_to trips_path, notice: "#{name} was permanently deleted, along with its rounds, golfers, matches and scores.", status: :see_other
  end

  def show
    @trip = find_trip!
    @can_manage = organizer_for?(@trip)
    @active_invitation = @trip.invitations.active.order(created_at: :desc).first if @can_manage
    @spectator_pass = @trip.spectator_passes.active.order(created_at: :desc).first if @can_manage
    @entries = Leaderboard.for(@trip)
    @cup_entries = CupStandings.for(@trip)
    @teams = @trip.teams.order(:name)
    @rounds = @trip.rounds.order(:plays_on, :id)
    @golf_courses = GolfCourse.order(:name).limit(250)
    @selected_course_id = GolfCourse.find_by(id: params[:selected_course_id])&.id
    @selected_tee = params[:selected_tee].to_s if @selected_course_id.present?
    @selected_tee = nil unless GolfCourse.find_by(id: @selected_course_id)&.tee_names&.include?(@selected_tee)
    requested_view = params[:view].to_s
    @view = %w[overview play standings manage].include?(requested_view) ? requested_view : (@selected_course_id ? "manage" : "overview")
    @view = "overview" if @view == "manage" && !@can_manage
    @pulse = TripPulse.new(@trip, cup_entries: @cup_entries)
    @focus_round = @pulse.focus_round
  end
  private

  def trip_params
    params.require(:trip).permit(:name, :destination, :starts_on, :ends_on)
  end
end
