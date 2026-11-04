class RecoveriesController < ApplicationController
  skip_before_action :require_authentication
  rate_limit to: 5, within: 10.minutes, only: :create

  def new; end

  def create
    @user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)
    unless @user && @user.valid_recovery_code?(params[:recovery_code])
      flash.now[:alert] = "Recovery details didn't match."
      return render :new, status: :unprocessable_entity
    end
    @user.with_lock do
      raise ActiveRecord::RecordNotFound unless @user.valid_recovery_code?(params[:recovery_code])
      @user.password = params[:password]
      @user.password_confirmation = params[:password_confirmation]
      @user.issue_recovery_code
      @user.save!
      @user.logins.destroy_all
    end
    pending_invite = session[:pending_invite]
    reset_session
    @current_login = nil
    start_login(@user)
    session[:pending_invite] = pending_invite
    @recovery_code = @user.recovery_code
    render "registrations/created"
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = @user.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end
end
