class SpectatorPassesController < ApplicationController
  def create
    trip = find_trip!(manage: true)
    trip.with_lock do
      trip.spectator_passes.active.first || trip.spectator_passes.create!
    end
    redirect_to trip_path(trip, view: "manage", anchor: "spectator-access"),
      notice: "Spectator broadcast enabled. Only people you share the link with can watch."
  end

  def destroy
    trip = find_trip!(manage: true)
    trip.spectator_passes.find(params[:id]).update!(revoked_at: Time.current)
    redirect_to trip_path(trip, view: "manage", anchor: "spectator-access"),
      notice: "The spectator link is revoked. Old links no longer work."
  end
end
