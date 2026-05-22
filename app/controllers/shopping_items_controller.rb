class ShoppingItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_shopping_item, only: [:destroy, :toggle_purchased]

  def index
    @shopping_item = current_user.shopping_items.new
    @shopping_items = current_user.shopping_items
                                  .includes(dish_ingredient: { plan_dish: :meal_plan })
                                  .order(:purchased, :manual, :created_at)
    @unpurchased_plan_groups = grouped_plan_items(@shopping_items.reject(&:purchased?).reject(&:manual?))
    @purchased_plan_groups = grouped_plan_items(@shopping_items.select(&:purchased?).reject(&:manual?))
    @manual_unpurchased_items = @shopping_items.reject(&:purchased?).select(&:manual?)
    @manual_purchased_items = @shopping_items.select(&:purchased?).select(&:manual?)
    @unpurchased_count = @shopping_items.count { |item| !item.purchased? }
    @purchased_count = @shopping_items.count(&:purchased?)
  end

  def create
    @shopping_item = current_user.shopping_items.new(shopping_item_params.merge(manual: true, purchased: false))

    if @shopping_item.save
      redirect_to shopping_items_path, notice: "買い物項目を追加しました"
    else
      prepare_index_state
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    group_items_for(@shopping_item).destroy_all
    redirect_to shopping_items_path, notice: "買い物項目を削除しました"
  end

  def toggle_purchased
    items = group_items_for(@shopping_item)
    next_state = !@shopping_item.purchased?
    items.each { |item| item.update!(purchased: next_state) }

    redirect_to shopping_items_path, notice: next_state ? "購入済みにしました" : "未購入に戻しました"
  end

  def destroy_purchased
    current_user.shopping_items.purchased.destroy_all
    redirect_to shopping_items_path, notice: "購入済み項目を削除しました"
  end

  private

  def set_shopping_item
    @shopping_item = current_user.shopping_items.find(params[:id])
  end

  def shopping_item_params
    params.fetch(:shopping_item, params).permit(:name)
  end

  def prepare_index_state
    @shopping_items = current_user.shopping_items
                                  .includes(dish_ingredient: { plan_dish: :meal_plan })
                                  .order(:purchased, :manual, :created_at)
    @unpurchased_plan_groups = grouped_plan_items(@shopping_items.reject(&:purchased?).reject(&:manual?))
    @purchased_plan_groups = grouped_plan_items(@shopping_items.select(&:purchased?).reject(&:manual?))
    @manual_unpurchased_items = @shopping_items.reject(&:purchased?).select(&:manual?)
    @manual_purchased_items = @shopping_items.select(&:purchased?).select(&:manual?)
    @unpurchased_count = @shopping_items.count { |item| !item.purchased? }
    @purchased_count = @shopping_items.count(&:purchased?)
  end

  def grouped_plan_items(items)
    items.group_by do |item|
      meal_plan = item.meal_plan
      [meal_plan&.meal_date, meal_plan&.meal_type, item.name.to_s.strip]
    end.map do |(meal_date, meal_type, name), group_items|
      {
        meal_date: meal_date,
        meal_type: meal_type,
        name: name,
        items: group_items,
        dishes: group_items.map { |item| item.plan_dish&.name }.compact.uniq
      }
    end.sort_by { |group| [group[:meal_date] || Date.new(9999, 12, 31), MealPlan.meal_types[group[:meal_type]] || 99, group[:name]] }
  end

  def group_items_for(item)
    return current_user.shopping_items.where(id: item.id) if item.manual?

    meal_plan = item.meal_plan
    return current_user.shopping_items.where(id: item.id) if meal_plan.blank?

    current_user.shopping_items
                .joins(dish_ingredient: { plan_dish: :meal_plan })
                .where(manual: false, purchased: item.purchased?, name: item.name.to_s.strip)
                .where(meal_plans: { meal_date: meal_plan.meal_date, meal_type: meal_plan.meal_type })
  end
end
