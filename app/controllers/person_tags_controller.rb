class PersonTagsController < ApplicationController
  before_action :authenticate_user!, except: :reorder
  before_action :authenticate_reorder_user!, only: :reorder
  before_action :set_person_tag, only: [:edit, :update, :destroy]

  def index
    @person_tags = current_user.person_tags.display_ordered
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
      @person_tags = current_user.person_tags.display_ordered
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

  def reorder
    unless request.media_type == "application/json"
      render json: { ok: false }, status: :unprocessable_content
      return
    end

    PersonTag.reorder_for!(user: current_user, ids: params[:ids])
    render json: { ok: true }
  rescue PersonTag::InvalidReorder, ActiveRecord::RecordInvalid
    render json: { ok: false }, status: :unprocessable_content
  end

  private

  def authenticate_reorder_user!
    return if logged_in?

    render json: { ok: false }, status: :unauthorized
  end

  def set_person_tag
    @person_tag = current_user.person_tags.find(params[:id])
  end

  def person_tag_params
    params.fetch(:person_tag, {}).permit(:name, :default_selected).tap do |permitted|
      permitted[:default_selected] = ActiveModel::Type::Boolean.new.cast(permitted[:default_selected])
    end
  end
end
