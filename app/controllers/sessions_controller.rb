class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [ :new, :create ]
  rate_limit to: 10, within: 3.minutes, only: :create

  def new; end

  def create
    pending_invite = session[:pending_invite]
    if params[:email_address].present?
      user = User.authenticate_by(email_address: params[:email_address].to_s.strip.downcase, password: params[:password].to_s)
      if user
        start_login(user, preserve_legacy: legacy_organizer?)
        session[:pending_invite] = pending_invite
        return redirect_to after_sign_in_path
      end
    else
      expected = ENV["ORGANIZER_PASSWORD"].presence
      if expected && ActiveSupport::SecurityUtils.secure_compare(params[:password].to_s, expected)
        current_login&.destroy!
        reset_session
        @current_login = nil
        session[:organizer] = true
        session[:pending_invite] = pending_invite
        return redirect_to after_sign_in_path
      end
    end
    flash.now[:alert] = "Sign-in details didn't match. Please try again."
    render :new, status: :unprocessable_entity
  end

  def destroy
    current_login&.destroy!
    reset_session
    redirect_to new_session_path
  end
end
