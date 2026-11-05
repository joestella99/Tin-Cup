class RoundsController < ApplicationController
  def create
    trip = find_trip!(manage: true)
    attributes = params.require(:round).permit(:course, :plays_on, :scoring_mode, :golf_course_id, :tee_name)
    selected_id = attributes.delete(:golf_course_id)
    selected_course = selected_id.present? ? GolfCourse.find(selected_id) : nil
    attributes[:course] = selected_course.name if selected_course
    attributes.delete(:tee_name) unless selected_course
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

  def destroy
    trip = find_trip!(manage: true)
    round = trip.rounds.find(params[:id])
    course = round.course
    trip.with_lock { round.destroy! }
    redirect_to trip_path(trip, view: "manage", anchor: "manage-rounds"),
      notice: "#{course} removed from the itinerary, including its scores and matches.", status: :see_other
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

  # Cart Mode is deliberately separate from the long-form administrative card.
  # We remember the golfer for this trip in their current browser session.
  def cart
    @trip = find_trip!
    @round = @trip.rounds.find(params[:id])
    unless @round.hole_by_hole? && @round.course_confirmed?
      return redirect_to trip_round_path(@trip, @round),
        alert: "Confirm a hole-by-hole course card before Cart Mode can start."
    end

    @players = @trip.players.includes(:team).order(:name).to_a
    session_key = "cart_player_#{@trip.id}"
    if params[:player_id].present?
      @scoring_player = @trip.players.find(params[:player_id])
      session[session_key] = @scoring_player.id
    else
      @scoring_player = @players.find { |player| player.id == session[session_key].to_i }
    end

    return unless @scoring_player

    @card = CartScorecard.new(@round, @scoring_player)
    @hole = params[:hole].present? ? @round.holes.find_by!(number: params[:hole]) : @card.next_hole
    @previous_score = @card.score_for(@hole)
    @score_choices = @card.suggestions(@hole)
    @match = @round.matches.includes(:home_player, :away_player).find do |match|
      match.home_player_id == @scoring_player.id || match.away_player_id == @scoring_player.id
    end
    @match_result = MatchResult.for(@match) if @match
    result = flash[:cart_result]
    @cart_feedback = result if result.is_a?(Hash) &&
      result["round_id"].to_i == @round.id && result["player_id"].to_i == @scoring_player.id
  end

  def show
    @trip = find_trip!
    @round = @trip.rounds.find(params[:id])
    @players = @trip.players.order(:name)
    @can_manage = organizer_for?(@trip)
    @scores = @round.scores.index_by(&:player_id)
    @results = RoundResults.for(@round)
    if @round.hole_by_hole?
      requested_player = @players.find_by(id: params[:player_id]) if params[:player_id].present? && params[:player_id] != "all"
      @scoring_player = requested_player || (@players.first if @players.size > 4 && params[:player_id] != "all")
      @scoring_players = @scoring_player ? [ @scoring_player ] : @players
      scored = @round.hole_scores
      scored = scored.where(player_id: @scoring_player.id) if @scoring_player
      @scored_hole_ids = scored.distinct.pluck(:hole_id)
      first_open_hole = @round.holes.order(:number).find { |hole| !@scored_hole_ids.include?(hole.id) }
      @hole = @round.holes.find_by(number: params[:hole].presence || (first_open_hole&.number || 1))
    end
    @hole_scores = @hole ? @hole.hole_scores.index_by(&:player_id) : {}
    @matches = @round.matches.includes(:home_player, :away_player).order(:id)
    @available_players = @players.where.not(id: @matches.flat_map { |m| [ m.home_player_id, m.away_player_id ] }).where.not(team_id: nil)
  end
end
