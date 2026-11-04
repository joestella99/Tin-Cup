class RoundsController < ApplicationController
  def create
    trip = Trip.find(params[:trip_id])
    round = trip.rounds.build(params.require(:round).permit(:course, :plays_on, :scoring_mode))
    if round.save
      redirect_to trip, notice: "Round added to the itinerary."
    else
      redirect_to trip, alert: round.errors.full_messages.to_sentence
    end
  end

  def show
    @trip = Trip.find(params[:trip_id])
    @round = @trip.rounds.find(params[:id])
    @players = @trip.players.order(:name)
    @scores = @round.scores.index_by(&:player_id)
    @results = RoundResults.for(@round)
    @hole = @round.holes.find_by(number: params[:hole].presence || 1) if @round.hole_by_hole?
    @hole_scores = @hole ? @hole.hole_scores.index_by(&:player_id) : {}
    @matches = @round.matches.includes(:home_player, :away_player).order(:id)
    @available_players = @players.where.not(id: @matches.flat_map { |m| [ m.home_player_id, m.away_player_id ] }).where.not(team_id: nil)
  end
end
