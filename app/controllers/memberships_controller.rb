class MembershipsController < ApplicationController
  def destroy
    trip = find_trip!(manage: true)
    membership = trip.memberships.find(params[:id])
    raise ActiveRecord::RecordNotFound if membership.owner?
    membership.destroy!
    redirect_to trip, notice: "Member access removed. Revoke the invite link too if it should no longer be used."
  end
end
