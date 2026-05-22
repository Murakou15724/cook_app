module MealPlansHelper
  def meal_type_label(meal_type)
    { "lunch" => "昼食", "dinner" => "夕食" }.fetch(meal_type.to_s, meal_type.to_s)
  end
end
