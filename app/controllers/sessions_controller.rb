class SessionsController < ApplicationController
  skip_before_action :require_organizer, only: [ :new, :create ]
  rate_limit to: 10, within: 3.minutes, only: :create

  def new; end

  def create
    expected = ENV["ORGANIZER_PASSWORD"].presence
    if expected && ActiveSupport::SecurityUtils.secure_compare(params[:password].to_s, expected)
      reset_session
      session[:organizer] = true
      redirect_to trips_path
    else
      flash.now[:alert] = "That password didn't match. Check your organizer password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path
  end
end
