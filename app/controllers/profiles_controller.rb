class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    attrs = profile_params.to_h.compact_blank

    if @user.update(attrs)
      redirect_to edit_profile_path, notice: "プロフィールを更新しました"
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def profile_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
