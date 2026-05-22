module Admin
  class UsersController < BaseController
    before_action :set_user, only: [:edit, :update, :destroy]

    def index
      @users = User.order(:created_at)
    end

    def edit
    end

    def update
      redirect_to admin_users_path, notice: "ユーザー更新は後続issueで実装します"
    end

    def destroy
      redirect_to admin_users_path, notice: "ユーザー削除は後続issueで実装します"
    end

    private

    def set_user
      @user = User.find(params[:id])
    end
  end
end
