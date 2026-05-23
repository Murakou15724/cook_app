module ApplicationHelper
  def app_date(date, with_year: false)
    return "" if date.blank?

    with_year ? date.strftime("%Y/%m/%d") : date.strftime("%m/%d")
  end

  def shopping_item_context(item)
    meal_plan = item.meal_plan
    plan_dish = item.plan_dish

    return "手動追加" if meal_plan.blank? || plan_dish.blank?

    "#{app_date(meal_plan.meal_date)}/#{shopping_meal_type_label(meal_plan.meal_type)} #{plan_dish.name}"
  end

  def shopping_meal_type_label(meal_type)
    { "lunch" => "昼", "dinner" => "夕" }.fetch(meal_type.to_s, meal_type.to_s)
  end
end
