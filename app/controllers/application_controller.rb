class ApplicationController < ActionController::Base
  before_action :require_organizer

  private

  def require_organizer
    redirect_to new_session_path unless session[:organizer] == true
  end
end
