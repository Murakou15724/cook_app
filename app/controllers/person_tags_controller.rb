class PersonTagsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_person_tag, only: [:edit, :update, :destroy]

  def index
    @person_tags = current_user.person_tags.order(:name)
    @person_tag = current_user.person_tags.new
  end

  def new
    @person_tag = current_user.person_tags.new
  end

  def create
    redirect_to person_tags_path, notice: "人物タグ作成は後続issueで実装します"
  end

  def edit
  end

  def update
    redirect_to person_tags_path, notice: "人物タグ更新は後続issueで実装します"
  end

  def destroy
    redirect_to person_tags_path, notice: "人物タグ削除は後続issueで実装します"
  end

  private

  def set_person_tag
    @person_tag = current_user.person_tags.find(params[:id])
  end
end
