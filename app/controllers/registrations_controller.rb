class RegistrationsController < ApplicationController
  skip_before_action :require_authentication
  rate_limit to: 5, within: 10.minutes, only: :create

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.require(:user).permit(:name, :email_address, :password, :password_confirmation))
    if @user.save
      pending_invite = session[:pending_invite]
      start_login(@user, preserve_legacy: legacy_organizer?)
      session[:pending_invite] = pending_invite
      @recovery_code = @user.recovery_code
      render :created, status: :created
    else
      render :new, status: :unprocessable_entity
    end
  end
end
