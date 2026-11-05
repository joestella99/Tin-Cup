# Deliberately public read-only broadcast. A random signed token is required;
# trip and organizer endpoints remain authenticated and unchanged.
class SpectatorsController < ApplicationController
  skip_before_action :require_authentication
  before_action :load_broadcast
  before_action :prevent_indexing

  def show
  end

  def live
    render partial: "spectators/live", locals: { board: @board, pulse: @pulse, trip: @trip }
  end

  private

  def load_broadcast
    @pass = SpectatorPass.find_signed(params[:token], purpose: :trip_spectator)
    raise ActiveRecord::RecordNotFound unless @pass&.active?

    @trip = @pass.trip
    @board = Clubhouse.for(@trip)
    @pulse = TripPulse.new(@trip, cup_entries: @board.cup_standings)
  end

  def prevent_indexing
    response.headers["X-Robots-Tag"] = "noindex, nofollow, noarchive"
  end
end
