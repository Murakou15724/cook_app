class AllowManualCookingRecords < ActiveRecord::Migration[7.1]
  def change
    change_column_null :cooking_records, :source_meal_plan_id, true
    change_column_null :cooking_records, :source_plan_dish_id, true
  end
end
