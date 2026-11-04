class InvitationsController < ApplicationController
  def create
    trip = find_trip!(manage: true)
    return redirect_to trip, alert: "Create a personal account and claim this trip before inviting your group." unless trip.ownership
    trip.with_lock do
      trip.invitations.active.update_all(revoked_at: Time.current)
      trip.invitations.create!(expires_at: 14.days.from_now)
    end
    redirect_to trip, notice: "A new invite link is ready. Previous links have been revoked."
  end

  def destroy
    trip = find_trip!(manage: true)
    trip.invitations.find(params[:id]).update!(revoked_at: Time.current)
    redirect_to trip, notice: "Invite link revoked. Existing members still have access."
  end
end
