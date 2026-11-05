class SkinsGamesController < ApplicationController
  def show
    @trip = find_trip!
    @round = @trip.rounds.find(params[:round_id])
    raise ActiveRecord::RecordNotFound unless @round.hole_by_hole?
    @game = SkinsGame.for(@round)
  end
end
