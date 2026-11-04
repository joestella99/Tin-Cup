class ApplicationController < ActionController::Base
  before_action :require_authentication
  before_action :protect_private_responses
  helper_method :current_user, :signed_in?, :legacy_organizer?, :organizer_for?

  private

  def current_login
    @current_login ||= Login.active.includes(:user).find_by(id: session[:login_id]) if session[:login_id]
  end

  def current_user
    current_login&.user
  end

  def legacy_organizer?
    session[:organizer] == true
  end

  def signed_in?
    current_user.present? || legacy_organizer?
  end

  def require_authentication
    redirect_to new_session_path unless signed_in?
  end

  def protect_private_responses
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
  end

  def accessible_trips
    ids = current_user ? current_user.memberships.select(:trip_id) : Membership.none.select(:trip_id)
    trips = Trip.where(id: ids)
    legacy_organizer? ? trips.or(Trip.unclaimed) : trips
  end

  def organizer_for?(trip)
    (current_user && trip.memberships.exists?(user_id: current_user.id, role: "owner")) || (legacy_organizer? && !trip.ownership)
  end

  def find_trip!(manage: false)
    trip = accessible_trips.find(params[:trip_id].presence || params[:id])
    raise ActiveRecord::RecordNotFound if manage && !organizer_for?(trip)
    trip
  end

  def start_login(user, preserve_legacy: false)
    current_login&.destroy!
    reset_session
    @current_login = user.logins.create!(expires_at: 14.days.from_now)
    session[:login_id] = @current_login.id
    session[:organizer] = true if preserve_legacy
  end

  def after_sign_in_path
    if session[:pending_invite].present?
      join_path(session[:pending_invite])
    else
      trips_path
    end
  end
end
