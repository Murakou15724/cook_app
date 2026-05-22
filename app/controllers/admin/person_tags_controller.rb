module Admin
  class PersonTagsController < BaseController
    before_action :set_person_tag, only: [:show, :edit, :update, :destroy]

    def index
      @person_tags = PersonTag.includes(:user).order(:name)
    end

    def show
    end

    def edit
    end

    def update
      redirect_to admin_person_tag_path(@person_tag), notice: "管理者人物タグ更新は後続issueで実装します"
    end

    def destroy
      redirect_to admin_person_tags_path, notice: "管理者人物タグ削除は後続issueで実装します"
    end

    private

    def set_person_tag
      @person_tag = PersonTag.find(params[:id])
    end
  end
end
