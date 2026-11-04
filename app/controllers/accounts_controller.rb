class AccountsController < ApplicationController
  def show
    redirect_to new_registration_path unless current_user
  end
end
