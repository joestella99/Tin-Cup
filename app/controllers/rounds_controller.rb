class RoundsController < ApplicationController
  def create
    trip = find_trip!(manage: true)
    attributes = params.require(:round).permit(:course, :plays_on, :scoring_mode, :golf_course_id)
    selected_id = attributes.delete(:golf_course_id)
    selected_course = selected_id.present? ? GolfCourse.find(selected_id) : nil
    attributes[:course] = selected_course.name if selected_course
    round = trip.rounds.build(attributes)
    round.golf_course = selected_course
    trip.with_lock do
      round.save!
      round.copy_library_scorecard!
    end
    message = selected_course && round.course_confirmed? ? "Round scheduled with its 18-hole course card ready to play." : "Round added to the itinerary."
    redirect_to trip, notice: message
  rescue ActiveRecord::RecordInvalid => error
    redirect_to trip, alert: error.record.errors.full_messages.to_sentence
  end

  def edit
    @trip = find_trip!(manage: true)
    @round = @trip.rounds.find(params[:id])
  end

  def update
    @trip = find_trip!(manage: true)
    @round = @trip.rounds.find(params[:id])
    changes = params.require(:round).permit(:course, :plays_on)

    if @trip.with_lock { @round.update(changes) }
      redirect_to trip_round_path(@trip, @round), notice: "Round schedule updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def show
    @trip = find_trip!
    @round = @trip.rounds.find(params[:id])
    @players = @trip.players.order(:name)
    @can_manage = organizer_for?(@trip)
    @scores = @round.scores.index_by(&:player_id)
    @results = RoundResults.for(@round)
    @scored_hole_ids = @round.hole_scores.distinct.pluck(:hole_id) if @round.hole_by_hole?
    @hole = @round.holes.find_by(number: params[:hole].presence || 1) if @round.hole_by_hole?
    @hole_scores = @hole ? @hole.hole_scores.index_by(&:player_id) : {}
    @matches = @round.matches.includes(:home_player, :away_player).order(:id)
    @available_players = @players.where.not(id: @matches.flat_map { |m| [ m.home_player_id, m.away_player_id ] }).where.not(team_id: nil)
  end
end
