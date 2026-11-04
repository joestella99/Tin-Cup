class JoinsController < ApplicationController
  skip_before_action :require_authentication, only: :show
  before_action :load_invitation

  def show
    session[:pending_invite] = params[:token]
  end

  def create
    return redirect_to new_registration_path, alert: "Create a personal account to join this trip." unless current_user
    @invitation.with_lock do
      raise ActiveRecord::RecordNotFound unless @invitation.active?
      @invitation.trip.memberships.find_or_create_by!(user: current_user) { |m| m.role = :scorer }
    end
    session.delete(:pending_invite)
    redirect_to @invitation.trip, notice: "You're in! You can view the trip and enter scores for the group."
  end

  private

  def load_invitation
    @invitation = Invitation.find_signed(params[:token], purpose: :trip_invite)
    raise ActiveRecord::RecordNotFound unless @invitation&.active?
  end
end
