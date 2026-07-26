class MealPlansController < ApplicationController
  before_action :authenticate_user!
  before_action :migrate_past_meal_plans!, only: [:index]
  before_action :set_editable_meal_plan, only: [:edit, :update]
  before_action :set_meal_plan, only: [:destroy, :move_dish]

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

    if past_meal_date?(@meal_plan.meal_date)
      @meal_plan.valid?
      @meal_plan.errors.add(:meal_date, "は今日以降を指定してください")
      render :new, status: :unprocessable_content
      return
    end

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
    @selected_person_tag_ids = selected_update_person_tag_ids
    @dish_inputs = normalized_update_dish_inputs
    @meal_plan.assign_attributes(update_meal_plan_attributes)
    validate_full_update_input!
    sync_full_update!
    redirect_to meal_plans_path, notice: "献立を更新しました"
  rescue ActiveRecord::RecordInvalid => error
    merge_nested_errors(error.record)
    render :edit, status: :unprocessable_content
  rescue ActiveRecord::RecordNotUnique
    @meal_plan.errors.add(:base, "同じ日付と食事区分の献立は既に登録されています")
    render :edit, status: :unprocessable_content
  rescue ActiveRecord::RecordNotDestroyed => error
    merge_nested_errors(error.record)
    @meal_plan.errors.add(:base, "献立を更新できませんでした") if @meal_plan.errors.empty?
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

  def set_editable_meal_plan
    @meal_plan = current_user.meal_plans.active.find(params[:id])
  end

  def meal_plan_params
    {
      meal_date: params[:meal_date],
      meal_type: permitted_meal_type
    }
  end

  def full_update_params
    params.permit(
      :meal_date,
      :meal_type,
      person_tag_ids: [],
      dishes: [
        :id,
        :name,
        :memo,
        { ingredients: [:id, :name, :add_to_shopping_list] }
      ]
    )
  end

  def update_meal_plan_attributes
    permitted = full_update_params
    meal_type = permitted[:meal_type].to_s

    {
      meal_date: permitted[:meal_date],
      meal_type: MealPlan.meal_types.key?(meal_type) ? meal_type : nil
    }
  end

  def permitted_meal_type
    meal_type = params[:meal_type].to_s
    return meal_type if MealPlan.meal_types.key?(meal_type)

    nil
  end

  def past_meal_date?(meal_date)
    meal_date.present? && meal_date < Date.current
  end

  def selected_person_tag_ids
    current_user.person_tags.where(id: Array(params[:person_tag_ids])).pluck(:id)
  end

  def selected_update_person_tag_ids
    current_user.person_tags.where(id: Array(full_update_params[:person_tag_ids])).pluck(:id)
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

  def normalized_update_dish_inputs
    raw_dishes = validated_update_collection(full_update_params[:dishes]).to_h.values

    raw_dishes.map do |dish|
      {
        "id" => dish["id"].presence&.to_s,
        "name" => dish["name"].to_s.strip,
        "memo" => dish["memo"].to_s.strip,
        "ingredients" => normalized_update_ingredient_inputs(dish)
      }
    end
  end

  def normalized_update_ingredient_inputs(dish)
    raw_ingredients = validated_update_collection(dish["ingredients"]).to_h.values

    raw_ingredients.filter_map do |ingredient|
      id = ingredient["id"].presence&.to_s
      name = ingredient["name"].to_s.strip
      next if id.blank? && name.blank?

      {
        "id" => id,
        "name" => name,
        "add_to_shopping_list" => ActiveModel::Type::Boolean.new.cast(ingredient["add_to_shopping_list"])
      }
    end
  end

  def validated_update_collection(collection)
    return {} if collection.nil?

    valid_container = collection.is_a?(ActionController::Parameters) || collection.is_a?(Hash)
    valid_entries = valid_container &&
                    collection.keys.all? { |key| key.to_s.match?(/\A\d+\z/) } &&
                    collection.values.all? do |value|
                      value.is_a?(ActionController::Parameters) || value.is_a?(Hash)
                    end
    return collection if valid_entries

    @dish_inputs = dish_inputs_from_meal_plan(@meal_plan)
    reject_full_update!("送信された料理または食材の形式が正しくありません")
  end

  def validate_full_update_input!
    reject_full_update!("料理を1件以上入力してください") if @dish_inputs.empty?
    reject_full_update!("料理名を入力してください") if @dish_inputs.any? { |dish| dish["name"].blank? }
    reject_full_update!("日付は今日以降を指定してください") if past_meal_date?(@meal_plan.meal_date)

    dish_ids = @dish_inputs.filter_map { |dish| dish["id"] }
    reject_full_update!("同じ料理が重複して送信されています") if duplicate_record_ids?(dish_ids)

    ingredient_ids = @dish_inputs.flat_map do |dish|
      dish["ingredients"].filter_map { |ingredient| ingredient["id"] }
    end
    reject_full_update!("同じ食材が重複して送信されています") if duplicate_record_ids?(ingredient_ids)
  end

  def duplicate_record_ids?(values)
    normalized_values = values.map { |value| value.to_i }
    normalized_values.length != normalized_values.uniq.length
  end

  def reject_full_update!(message)
    @meal_plan.valid?
    @meal_plan.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, @meal_plan
  end

  def sync_full_update!
    ActiveRecord::Base.transaction do
      @meal_plan = current_user.meal_plans.active.lock.find(@meal_plan.id)
      @meal_plan.assign_attributes(update_meal_plan_attributes)

      dish_by_id, ingredient_by_id, dishes_to_delete = validate_full_update_ids!
      reject_cooking_record_dish_deletion!(dishes_to_delete)

      @meal_plan.save!
      sync_person_tags_for_full_update!
      sync_dishes_for_full_update!(dish_by_id, ingredient_by_id)
      destroy_removed_dishes!(dishes_to_delete)
    end
  end

  def validate_full_update_ids!
    existing_dishes = @meal_plan.plan_dishes.to_a
    submitted_dish_ids = @dish_inputs.filter_map { |dish| dish["id"] }.map(&:to_i)
    dish_by_id = existing_dishes.select { |dish| submitted_dish_ids.include?(dish.id) }.index_by(&:id)
    raise ActiveRecord::RecordNotFound if dish_by_id.length != submitted_dish_ids.length

    ingredient_by_id = {}
    @dish_inputs.each do |dish_input|
      ingredient_ids = dish_input["ingredients"].filter_map { |ingredient| ingredient["id"] }.map(&:to_i)
      next if ingredient_ids.empty?
      raise ActiveRecord::RecordNotFound if dish_input["id"].blank?

      dish = dish_by_id.fetch(dish_input["id"].to_i)
      scoped_ingredients = dish.dish_ingredients.where(id: ingredient_ids).to_a
      raise ActiveRecord::RecordNotFound if scoped_ingredients.length != ingredient_ids.length

      ingredient_by_id.merge!(scoped_ingredients.index_by(&:id))
    end

    dishes_to_delete = existing_dishes.reject { |dish| submitted_dish_ids.include?(dish.id) }
    [dish_by_id, ingredient_by_id, dishes_to_delete]
  end

  def reject_cooking_record_dish_deletion!(dishes)
    return unless CookingRecord.where(source_plan_dish_id: dishes.map(&:id)).exists?

    reject_full_update!("調理記録がある料理は削除できません。画面を再読み込みしてください")
  end

  def sync_person_tags_for_full_update!
    current_ids = @meal_plan.person_tag_ids.sort
    selected_ids = @selected_person_tag_ids.map(&:to_i).sort
    @meal_plan.person_tag_ids = selected_ids unless current_ids == selected_ids
  end

  def sync_dishes_for_full_update!(dish_by_id, ingredient_by_id)
    surviving_positions = dish_by_id.values.map(&:position)
    next_position = surviving_positions.max.to_i
    next_position = -1 if surviving_positions.empty?

    @dish_inputs.each do |dish_input|
      if dish_input["id"].present?
        dish = dish_by_id.fetch(dish_input["id"].to_i)
        sync_existing_dish_for_full_update!(dish, dish_input)
        sync_ingredients_for_full_update!(dish, dish_input, ingredient_by_id)
      else
        next_position += 1
        dish = @meal_plan.plan_dishes.create!(
          name: dish_input["name"],
          memo: dish_input["memo"],
          eating_out: false,
          position: next_position
        )
        create_ingredients_for_full_update!(dish, dish_input["ingredients"])
      end
    end
  end

  def sync_existing_dish_for_full_update!(dish, input)
    attributes = { name: input["name"] }
    attributes[:memo] = input["memo"] unless dish.memo.blank? && input["memo"].blank?
    update_record_if_changed!(dish, attributes)
  end

  def sync_ingredients_for_full_update!(dish, dish_input, ingredient_by_id)
    submitted_ids = dish_input["ingredients"].filter_map { |ingredient| ingredient["id"] }.map(&:to_i)
    existing_ingredients = dish.dish_ingredients.to_a

    dish_input["ingredients"].each do |ingredient_input|
      if ingredient_input["id"].present?
        ingredient = ingredient_by_id.fetch(ingredient_input["id"].to_i)
        next if ingredient_input["name"].blank?

        sync_existing_full_ingredient!(ingredient, ingredient_input)
      else
        create_full_ingredient!(dish, ingredient_input)
      end
    end

    existing_ingredients.each do |ingredient|
      next if submitted_ids.include?(ingredient.id) &&
              dish_input["ingredients"].any? { |input| input["id"].to_i == ingredient.id && input["name"].present? }

      ingredient.destroy!
    end
  end

  def create_ingredients_for_full_update!(dish, ingredient_inputs)
    ingredient_inputs.each { |input| create_full_ingredient!(dish, input) }
  end

  def create_full_ingredient!(dish, input)
    return if input["name"].blank?

    ingredient = dish.dish_ingredients.create!(
      name: input["name"],
      add_to_shopping_list: input["add_to_shopping_list"]
    )
    create_shopping_item_for_full_ingredient!(ingredient) if ingredient.add_to_shopping_list?
  end

  def sync_existing_full_ingredient!(ingredient, input)
    old_name = ingredient.name
    old_add_to_shopping_list = ingredient.add_to_shopping_list?
    new_name = input["name"]
    new_add_to_shopping_list = input["add_to_shopping_list"]

    update_record_if_changed!(
      ingredient,
      name: new_name,
      add_to_shopping_list: new_add_to_shopping_list
    )

    return if old_name == new_name && old_add_to_shopping_list == new_add_to_shopping_list

    if new_add_to_shopping_list
      shopping_items = current_user.shopping_items.where(dish_ingredient: ingredient).order(:id).to_a
      if shopping_items.any?
        shopping_items.each { |shopping_item| update_record_if_changed!(shopping_item, name: new_name) }
      else
        create_shopping_item_for_full_ingredient!(ingredient)
      end
    else
      destroy_shopping_items_for_full_ingredient!(ingredient)
    end
  end

  def create_shopping_item_for_full_ingredient!(ingredient)
    current_user.shopping_items.create!(
      dish_ingredient: ingredient,
      name: ingredient.name,
      manual: false,
      purchased: false
    )
  end

  def destroy_shopping_items_for_full_ingredient!(ingredient)
    current_user.shopping_items.where(dish_ingredient: ingredient).find_each(&:destroy!)
  end

  def update_record_if_changed!(record, attributes)
    record.assign_attributes(attributes)
    record.save! if record.changed?
  end

  def destroy_removed_dishes!(dishes)
    dishes.each(&:destroy!)
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
          "id" => ingredient.id,
          "name" => ingredient.name,
          "add_to_shopping_list" => ingredient.add_to_shopping_list
        }
      end

      {
        "id" => dish.id,
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
