class MealPlansController < ApplicationController
  before_action :authenticate_user!
  before_action :migrate_past_meal_plans!, only: [:index]
  before_action :set_meal_plan, only: [:edit, :update, :destroy, :move_dish]

  def index
    prepare_index_state
  end

  def new
    @meal_plan = current_user.meal_plans.new(meal_date: Date.current)
    @person_tags = current_user.person_tags.order(:name)
    @dish_inputs = default_dish_inputs
  end

  def create
    @meal_plan = current_user.meal_plans.new(meal_plan_params)
    @person_tags = current_user.person_tags.order(:name)
    @dish_inputs = normalized_dish_inputs
    @selected_person_tag_ids = selected_person_tag_ids

    if @dish_inputs.empty?
      @dish_inputs = default_dish_inputs
      @meal_plan.valid?
      @meal_plan.errors.add(:base, "料理を1件以上入力してください")
      render :new, status: :unprocessable_content
      return
    end

    save_meal_plan!
    redirect_to meal_plans_path, notice: "献立を作成しました"
  rescue ActiveRecord::RecordInvalid => error
    merge_nested_errors(error.record)
    render :new, status: :unprocessable_content
  rescue ActiveRecord::RecordNotUnique
    @meal_plan.errors.add(:base, "同じ日付と食事区分の献立は既に登録されています")
    render :new, status: :unprocessable_content
  end

  def edit
    @person_tags = current_user.person_tags.order(:name)
    @selected_person_tag_ids = @meal_plan.person_tag_ids
    @dish_inputs = dish_inputs_from_meal_plan(@meal_plan)
  end

  def update
    if params[:quick_update].present?
      quick_update
      return
    end

    @person_tags = current_user.person_tags.order(:name)
    @dish_inputs = normalized_dish_inputs
    @selected_person_tag_ids = selected_person_tag_ids
    @meal_plan.assign_attributes(meal_plan_params)

    if @dish_inputs.empty?
      @dish_inputs = default_dish_inputs
      @meal_plan.valid?
      @meal_plan.errors.add(:base, "料理を1件以上入力してください")
      render :edit, status: :unprocessable_content
      return
    end

    save_meal_plan!(replace_existing: true)
    redirect_to meal_plans_path, notice: "献立を更新しました"
  rescue ActiveRecord::RecordInvalid => error
    merge_nested_errors(error.record)
    render :edit, status: :unprocessable_content
  rescue ActiveRecord::RecordNotUnique
    @meal_plan.errors.add(:base, "同じ日付と食事区分の献立は既に登録されています")
    render :edit, status: :unprocessable_content
  end

  def destroy
    @meal_plan.destroy
    redirect_to meal_plans_path, notice: "献立を削除しました"
  end

  def move_dish
    redirect_to edit_meal_plan_path(@meal_plan), notice: "並び替えは後続issueで実装します"
  end

  private

  def prepare_index_state
    @meal_plans = current_user.meal_plans.active.today_or_future
                              .includes(:person_tags, plan_dishes: :dish_ingredients)
                              .ordered
    @person_tags = current_user.person_tags.order(:name)
  end

  def quick_update
    @selected_person_tag_ids = selected_person_tag_ids

    ActiveRecord::Base.transaction do
      @meal_plan.person_tag_ids = @selected_person_tag_ids
      quick_dish_params.each do |dish_id, values|
        dish = @meal_plan.plan_dishes.find(dish_id)
        dish.update!(name: values[:name].to_s.strip, memo: values[:memo].to_s.strip)
      end
      sync_quick_ingredients!
    end

    respond_to do |format|
      format.html { redirect_to meal_plans_path, notice: "献立を更新しました" }
      format.turbo_stream { render_index_update("献立を更新しました") }
    end
  rescue ActiveRecord::RecordInvalid => error
    merge_nested_errors(error.record)
    respond_to do |format|
      format.html { render :edit, status: :unprocessable_content }
      format.turbo_stream { render_index_update(nil, status: :unprocessable_content) }
    end
  end

  def set_meal_plan
    @meal_plan = current_user.meal_plans.find(params[:id])
  end

  def meal_plan_params
    {
      meal_date: params[:meal_date],
      meal_type: permitted_meal_type
    }
  end

  def permitted_meal_type
    meal_type = params[:meal_type].to_s
    return meal_type if MealPlan.meal_types.key?(meal_type)

    nil
  end

  def selected_person_tag_ids
    current_user.person_tags.where(id: Array(params[:person_tag_ids])).pluck(:id)
  end

  def quick_dish_params
    params.fetch(:dishes, ActionController::Parameters.new).permit!.to_h.transform_values do |values|
      values.symbolize_keys.slice(:name, :memo)
    end
  end

  def quick_ingredient_params
    params.fetch(:ingredients, ActionController::Parameters.new).permit!.to_h.transform_values(&:symbolize_keys)
  end

  def sync_quick_ingredients!
    quick_ingredient_params.each_value do |values|
      if values[:id].present?
        sync_existing_quick_ingredient!(values)
      else
        create_quick_ingredient!(values)
      end
    end
  end

  def sync_existing_quick_ingredient!(values)
    ingredient = DishIngredient.joins(:plan_dish)
                               .where(plan_dishes: { meal_plan_id: @meal_plan.id })
                               .find(values[:id])

    if ActiveModel::Type::Boolean.new.cast(values[:delete])
      ingredient.destroy!
      return
    end

    add_to_shopping_list = ActiveModel::Type::Boolean.new.cast(values[:add_to_shopping_list])
    ingredient.update!(name: values[:name].to_s.strip, add_to_shopping_list: add_to_shopping_list)
    sync_shopping_item_for_quick_ingredient!(ingredient)
  end

  def create_quick_ingredient!(values)
    name = values[:name].to_s.strip
    return if name.blank?

    dish = @meal_plan.plan_dishes.find(values[:dish_id])
    ingredient = dish.dish_ingredients.create!(
      name: name,
      add_to_shopping_list: ActiveModel::Type::Boolean.new.cast(values[:add_to_shopping_list])
    )
    sync_shopping_item_for_quick_ingredient!(ingredient)
  end

  def sync_shopping_item_for_quick_ingredient!(ingredient)
    unless ingredient.add_to_shopping_list?
      ingredient.shopping_items.destroy_all
      return
    end

    shopping_item = current_user.shopping_items.find_or_initialize_by(dish_ingredient: ingredient)
    shopping_item.update!(
      dish_ingredient: ingredient,
      name: ingredient.name,
      manual: false,
      purchased: shopping_item.purchased? || false
    )
  end

  def default_dish_inputs
    [
      { "name" => "", "memo" => "", "ingredients" => default_ingredient_inputs }
    ]
  end

  def normalized_dish_inputs
    raw_dishes = params[:dishes].present? ? params[:dishes].to_unsafe_h.values : []

    raw_dishes.filter_map do |dish|
      normalized = {
        "name" => dish["name"].to_s.strip,
        "memo" => dish["memo"].to_s.strip,
        "ingredients" => normalized_ingredient_inputs(dish)
      }

      next if normalized["name"].blank? &&
              normalized["memo"].blank? &&
              ingredient_inputs(normalized).empty?

      normalized
    end
  end

  def save_meal_plan!(replace_existing: false)
    ActiveRecord::Base.transaction do
      @meal_plan.save!
      @meal_plan.person_tag_ids = @selected_person_tag_ids
      @meal_plan.plan_dishes.destroy_all if replace_existing

      @dish_inputs.each_with_index do |dish_input, index|
        dish = @meal_plan.plan_dishes.create!(
          name: dish_input["name"],
          memo: dish_input["memo"],
          eating_out: false,
          position: index
        )

        ingredient_inputs(dish_input).each do |ingredient_input|
          ingredient = dish.dish_ingredients.create!(
            name: ingredient_input["name"],
            add_to_shopping_list: ingredient_input["add_to_shopping_list"]
          )
          next unless ingredient.add_to_shopping_list?

          current_user.shopping_items.create!(
            dish_ingredient: ingredient,
            name: ingredient.name,
            manual: false,
            purchased: false
          )
        end
      end
    end
  end

  def default_ingredient_inputs
    Array.new(3) { { "name" => "", "add_to_shopping_list" => "1" } }
  end

  def dish_inputs_from_meal_plan(meal_plan)
    meal_plan.plan_dishes.ordered.includes(:dish_ingredients).map do |dish|
      ingredients = dish.dish_ingredients.order(:id).map do |ingredient|
        {
          "name" => ingredient.name,
          "add_to_shopping_list" => ingredient.add_to_shopping_list
        }
      end

      {
        "name" => dish.name,
        "memo" => dish.memo,
        "ingredients" => ingredients_with_default_blanks(ingredients)
      }
    end.presence || default_dish_inputs
  end

  def normalized_ingredient_inputs(dish)
    raw_ingredients = if dish["ingredients"].present?
                        dish["ingredients"].values
                      else
                        dish["ingredients_text"].to_s.lines.map do |line|
                          { "name" => line, "add_to_shopping_list" => dish["add_to_shopping_list"] }
                        end
                      end

    inputs = raw_ingredients.filter_map do |ingredient|
      name = ingredient["name"].to_s.strip
      next if name.blank?

      {
        "name" => name,
        "add_to_shopping_list" => ActiveModel::Type::Boolean.new.cast(ingredient["add_to_shopping_list"])
      }
    end

    inputs.presence || default_ingredient_inputs
  end

  def ingredient_inputs(dish_input)
    dish_input["ingredients"].to_a.select { |ingredient| ingredient["name"].present? }
  end

  def ingredients_with_default_blanks(ingredients)
    ingredients + Array.new([3 - ingredients.size, 0].max) { { "name" => "", "add_to_shopping_list" => "1" } }
  end

  def merge_nested_errors(record)
    return if record == @meal_plan

    record.errors.full_messages.each do |message|
      @meal_plan.errors.add(:base, message)
    end
  end

  def render_index_update(message, status: :ok)
    flash.now[:notice] = message if message.present?
    prepare_index_state
    render turbo_stream: [
      turbo_stream.update("flash-messages", partial: "shared/flash_messages"),
      turbo_stream.replace("meal_plans", partial: "meal_plans/list")
    ], status: status
  end
end
