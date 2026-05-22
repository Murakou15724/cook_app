class CookingRecordsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_cooking_record, only: [:show, :edit, :update, :destroy]

  def index
    @cooking_records = current_user.cooking_records.newest_first.includes(:person_tags)
  end

  def show
  end

  def edit
    @person_tags = current_user.person_tags.order(:name)
  end

  def update
    redirect_to cooking_record_path(@cooking_record), notice: "過去料理更新は後続issueで実装します"
  end

  def destroy
    redirect_to cooking_records_path, notice: "過去料理削除は後続issueで実装します"
  end

  private

  def set_cooking_record
    @cooking_record = current_user.cooking_records.find(params[:id])
  end
end
