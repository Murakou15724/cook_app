module Admin
  class RegistrationsController < ApplicationController
    http_basic_authenticate_with name: "admin", password: "Keiog00d"
    before_action :require_no_login!, only: [:new, :create]

    def new
      @user = User.new(role: :admin)
    end

    def create
      @user = User.new(admin_user_params.merge(role: :admin))

      if @user.save
        session[:user_id] = @user.id
        redirect_to admin_root_path, notice: "管理者を登録しました"
      else
        render :new, status: :unprocessable_content
      end
    end

    private

    def admin_user_params
      params.require(:user).permit(:email, :password, :password_confirmation)
    end
  end
end
