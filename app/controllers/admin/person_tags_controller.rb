module Admin
  class PersonTagsController < BaseController
    before_action :set_person_tag, only: [:destroy]

    def index
      @person_tags = PersonTag.includes(:user).order(:name)
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
