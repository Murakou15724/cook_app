class ShoppingItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_shopping_item, only: [:update, :destroy, :toggle_purchased]

  def index
    @shopping_item = current_user.shopping_items.new
    @shopping_items = current_user.shopping_items
                                  .includes(dish_ingredient: { plan_dish: :meal_plan })
                                  .display_ordered
    @unpurchased_items = @shopping_items.reject(&:purchased?)
    @purchased_items = @shopping_items.select(&:purchased?)
    @unpurchased_count = @shopping_items.count { |item| !item.purchased? }
    @purchased_count = @shopping_items.count(&:purchased?)
  end

  def create
    @shopping_item = current_user.shopping_items.new(shopping_item_params.merge(manual: true, purchased: false))

    if @shopping_item.save
      respond_to do |format|
        format.html { redirect_to shopping_items_path, notice: "買い物項目を追加しました" }
        format.turbo_stream { render_list_update("買い物項目を追加しました") }
      end
    else
      prepare_index_state
      respond_to do |format|
        format.html { render :index, status: :unprocessable_content }
        format.turbo_stream { render_list_update(nil, status: :unprocessable_content) }
      end
    end
  end

  def destroy
    group_items_for(@shopping_item).destroy_all
    respond_to do |format|
      format.html { redirect_to shopping_items_path, notice: "買い物項目を削除しました" }
      format.turbo_stream { render_list_update("買い物項目を削除しました") }
    end
  end

  def update
    if @shopping_item.update(shopping_item_params)
      respond_to do |format|
        format.html { redirect_to shopping_items_path, notice: "買い物項目を更新しました" }
        format.turbo_stream { render_list_update("買い物項目を更新しました") }
      end
    else
      prepare_index_state
      respond_to do |format|
        format.html { render :index, status: :unprocessable_content }
        format.turbo_stream { render_list_update(nil, status: :unprocessable_content) }
      end
    end
  end

  def toggle_purchased
    items = group_items_for(@shopping_item)
    next_state = !@shopping_item.purchased?
    items.each { |item| item.update!(purchased: next_state) }

    respond_to do |format|
      format.html { redirect_to shopping_items_path }
      format.turbo_stream { render_group_update }
    end
  end

  def destroy_purchased
    current_user.shopping_items.purchased.destroy_all
    respond_to do |format|
      format.html { redirect_to shopping_items_path, notice: "購入済み項目を削除しました" }
      format.turbo_stream { render_list_update("購入済み項目を削除しました") }
    end
  end

  def reorder
    ids = Array(params[:ids]).map(&:to_i)
    scoped_ids = current_user.shopping_items.unpurchased.where(id: ids).pluck(:id)

    ids.each_with_index do |id, index|
      next unless scoped_ids.include?(id)

      current_user.shopping_items.where(id: id).update_all(sort_order: (index + 1) * 1000, updated_at: Time.current)
    end

    respond_to do |format|
      format.html { redirect_to shopping_items_path, notice: "並び順を更新しました" }
      format.json { render json: { ok: true } }
    end
  end

  private

  def set_shopping_item
    @shopping_item = current_user.shopping_items.find(params[:id])
  end

  def shopping_item_params
    params.fetch(:shopping_item, params).permit(:name)
  end

  def prepare_index_state
    @shopping_item = current_user.shopping_items.new unless @shopping_item&.errors&.any?
    @shopping_items = current_user.shopping_items
                                  .includes(dish_ingredient: { plan_dish: :meal_plan })
                                  .display_ordered
    @unpurchased_items = @shopping_items.reject(&:purchased?)
    @purchased_items = @shopping_items.select(&:purchased?)
    @unpurchased_count = @shopping_items.count { |item| !item.purchased? }
    @purchased_count = @shopping_items.count(&:purchased?)
  end

  def group_items_for(item)
    current_user.shopping_items.where(id: item.id)
  end

  def render_list_update(message, status: :ok)
    flash.now[:notice] = message if message.present?
    prepare_index_state
    render turbo_stream: [
      turbo_stream.update("flash-messages", partial: "shared/flash_messages"),
      turbo_stream.replace("shopping_items", partial: "shopping_items/list")
    ], status: status
  end

  def render_group_update(status: :ok)
    prepare_index_state
    render turbo_stream: [
      turbo_stream.replace("shopping_unpurchased_group", partial: "shopping_items/unpurchased_group"),
      turbo_stream.replace("shopping_purchased_group", partial: "shopping_items/purchased_group")
    ], status: status
  end
end
