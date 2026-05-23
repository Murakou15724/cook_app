class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    attrs = profile_params.to_h
    attrs.delete("password") if attrs["password"].blank?
    attrs.delete("password_confirmation") if attrs["password_confirmation"].blank?

    if @user.update(attrs)
      redirect_to root_path, notice: "プロフィールを更新しました"
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def profile_params
    params.require(:user).permit(:email, :nickname, :password, :password_confirmation)
  end
end
