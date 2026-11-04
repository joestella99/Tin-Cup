class ClaimsController < ApplicationController
  def create
    raise ActiveRecord::RecordNotFound unless current_user && legacy_organizer?
    trip = find_trip!(manage: true)
    trip.with_lock do
      raise ActiveRecord::RecordNotFound if trip.ownership
      trip.memberships.create!(user: current_user, role: :owner)
    end
    redirect_to trip, notice: "This trip now belongs to your account. You can invite your group."
  end
end
