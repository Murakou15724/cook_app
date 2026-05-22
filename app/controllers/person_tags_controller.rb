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
    @person_tag = current_user.person_tags.new(person_tag_params)

    if @person_tag.save
      redirect_to person_tags_path, notice: "人物タグを作成しました"
    else
      @person_tags = current_user.person_tags.order(:name)
      render :index, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @person_tag.update(person_tag_params)
      redirect_to person_tags_path, notice: "人物タグを更新しました"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @person_tag.destroy
    redirect_to person_tags_path, notice: "人物タグを削除しました"
  end

  private

  def set_person_tag
    @person_tag = current_user.person_tags.find(params[:id])
  end

  def person_tag_params
    params.fetch(:person_tag, {}).permit(:name, :default_selected).tap do |permitted|
      permitted[:default_selected] = ActiveModel::Type::Boolean.new.cast(permitted[:default_selected])
    end
  end
end
