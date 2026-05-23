class CookingRecordsController < ApplicationController
  before_action :authenticate_user!
  before_action :migrate_past_meal_plans!, only: [:index]
  before_action :set_cooking_record, only: [:show, :edit, :update, :destroy]

  def index
    prepare_index_state
  end

  def show
  end

  def edit
    @person_tags = current_user.person_tags.order(:name)
  end

  def create
    @cooking_record = current_user.cooking_records.new(cooking_record_params.merge(eating_out: true))

    if save_cooking_record_with_tags(@cooking_record)
      respond_to do |format|
        format.html { redirect_to cooking_records_path(display_mode: "all"), notice: "外食記録を保存しました" }
        format.turbo_stream { render_index_update("外食記録を保存しました", display_mode: "all") }
      end
    else
      respond_to do |format|
        format.html do
          prepare_index_state(record: @cooking_record)
          render :index, status: :unprocessable_content
        end
        format.turbo_stream { render_index_update(nil, status: :unprocessable_content, record: @cooking_record) }
      end
    end
  end

  def update
    @cooking_record.assign_attributes(cooking_record_params)

    if save_cooking_record_with_tags(@cooking_record)
      redirect_to cooking_record_path(@cooking_record), notice: "過去料理を更新しました"
    else
      @person_tags = current_user.person_tags.order(:name)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @cooking_record.destroy
    redirect_to cooking_records_path(display_mode: "all"), notice: "過去料理を削除しました"
  end

  private

  def set_cooking_record
    @cooking_record = current_user.cooking_records.find(params[:id])
  end

  def prepare_index_state(display_mode: nil, record: nil)
    @person_tags = current_user.person_tags.order(:name)
    @cooking_record = record || current_user.cooking_records.new(cooked_on: Date.current, meal_type: :lunch, eating_out: true)
    @query = params[:q].to_s.strip
    @selected_person_tag_ids = selected_person_tag_ids
    @display_mode = display_mode || requested_display_mode
    @cooking_records = filtered_cooking_records.includes(:person_tags)
  end

  def filtered_cooking_records
    return CookingRecord.none if @display_mode == "none"

    records = current_user.cooking_records.newest_first
    records = apply_display_mode(records)
    records = apply_keyword_filter(records)
    apply_person_tag_filter(records)
  end

  def requested_display_mode
    params[:display_mode].presence || (searching? ? "all" : "none")
  end

  def searching?
    params[:q].present? || Array(params[:person_tag_ids]).reject(&:blank?).any?
  end

  def apply_display_mode(records)
    case @display_mode
    when "recent_lunch"
      records.where(cooked_on: 2.weeks.ago.to_date..Date.current, meal_type: :lunch)
    when "recent_dinner"
      records.where(cooked_on: 2.weeks.ago.to_date..Date.current, meal_type: :dinner)
    else
      records
    end
  end

  def apply_keyword_filter(records)
    return records if @query.blank?

    keyword = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
    condition = records.where("cooking_records.name LIKE :keyword OR cooking_records.memo LIKE :keyword", keyword: keyword)
    return condition unless @query == "外" || @query.include?("外食")

    records.where(id: condition.select(:id)).or(records.where(eating_out: true))
  end

  def apply_person_tag_filter(records)
    return records if @selected_person_tag_ids.empty?

    records.joins(:cooking_record_person_tags)
           .where(cooking_record_person_tags: { person_tag_id: @selected_person_tag_ids })
           .group("cooking_records.id")
           .having("COUNT(DISTINCT cooking_record_person_tags.person_tag_id) = ?", @selected_person_tag_ids.size)
  end

  def selected_person_tag_ids
    current_user.person_tags.where(id: Array(params[:person_tag_ids])).pluck(:id)
  end

  def cooking_record_params
    source = params[:cooking_record].presence || params
    source.permit(:name, :cooked_on, :meal_type, :memo, :eating_out)
  end

  def render_index_update(message, status: :ok, display_mode: nil, record: nil)
    flash.now[:notice] = message if message.present?
    prepare_index_state(display_mode: display_mode, record: record)
    render turbo_stream: [
      turbo_stream.update("flash-messages", partial: "shared/flash_messages"),
      turbo_stream.replace("cooking_records", partial: "cooking_records/index_content")
    ], status: status
  end

  def save_cooking_record_with_tags(record)
    ActiveRecord::Base.transaction do
      record.save!
      record.person_tag_ids = selected_person_tag_ids
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end
end
