class RecoveryCodesController < ApplicationController
  rate_limit to: 5, within: 10.minutes, only: :create

  def create
    @user = current_user
    raise ActiveRecord::RecordNotFound unless @user
    unless @user.authenticate(params[:password].to_s)
      return redirect_to account_path, alert: "Your current password didn't match."
    end
    @user.with_lock do
      @user.issue_recovery_code
      @user.save!
    end
    @recovery_code = @user.recovery_code
    render "registrations/created", status: :created
  end
end
