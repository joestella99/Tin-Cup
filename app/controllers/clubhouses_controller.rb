class ClubhousesController < ApplicationController
  before_action :load_clubhouse

  def show
  end

  def live
    render partial: "clubhouses/live", locals: { trip: @trip, board: @board }
  end

  private

  def load_clubhouse
    @trip = find_trip!
    selected_round = @trip.rounds.find(params[:round_id]) if params[:round_id].present?
    @board = Clubhouse.for(@trip, round: selected_round)
  end
end
