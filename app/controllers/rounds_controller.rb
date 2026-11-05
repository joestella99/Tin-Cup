class RoundsController < ApplicationController
  def create
    trip = find_trip!(manage: true)
    round = trip.rounds.build(params.require(:round).permit(:course, :plays_on, :scoring_mode))
    if trip.with_lock { round.save }
      redirect_to trip, notice: "Round added to the itinerary."
    else
      redirect_to trip, alert: round.errors.full_messages.to_sentence
    end
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
    @hole = @round.holes.find_by(number: params[:hole].presence || 1) if @round.hole_by_hole?
    @hole_scores = @hole ? @hole.hole_scores.index_by(&:player_id) : {}
    @matches = @round.matches.includes(:home_player, :away_player).order(:id)
    @available_players = @players.where.not(id: @matches.flat_map { |m| [ m.home_player_id, m.away_player_id ] }).where.not(team_id: nil)
  end
end
