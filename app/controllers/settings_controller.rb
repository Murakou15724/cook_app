class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @passkeys = current_user.passkeys.order(created_at: :desc)
  end
end
