class AddDatabaseDesignConstraints < ActiveRecord::Migration[7.1]
  def change
    add_check_constraint :users,
                         "role IN (0, 1)",
                         name: "chk_users_role"

    add_check_constraint :meal_plans,
                         "meal_type IN (0, 1)",
                         name: "chk_meal_plans_meal_type"

    add_check_constraint :meal_plans,
                        "((migrated IS FALSE AND migrated_at IS NULL) OR (migrated IS TRUE AND migrated_at IS NOT NULL))",
                        name: "chk_meal_plans_migrated_at"

    add_check_constraint :plan_dishes,
                         "CHAR_LENGTH(TRIM(name)) > 0",
                         name: "chk_plan_dishes_name_present"
    add_check_constraint :plan_dishes,
                         "position >= 0",
                         name: "chk_plan_dishes_position"

    add_check_constraint :dish_ingredients,
                         "CHAR_LENGTH(TRIM(name)) > 0",
                         name: "chk_dish_ingredients_name_present"

    add_check_constraint :shopping_items,
                         "CHAR_LENGTH(TRIM(name)) > 0",
                         name: "chk_shopping_items_name_present"
    add_check_constraint :shopping_items,
                         "((manual IS TRUE AND dish_ingredient_id IS NULL) OR (manual IS FALSE AND dish_ingredient_id IS NOT NULL))"
                         name: "chk_shopping_items_manual_source"
    add_check_constraint :shopping_items,
                         "((purchased IS FALSE AND purchased_at IS NULL) OR (purchased IS TRUE AND purchased_at IS NOT NULL))"
                         name: "chk_shopping_items_purchased_at"

    add_check_constraint :cooking_records,
                         "meal_type IN (0, 1)",
                         name: "chk_cooking_records_meal_type"
    add_check_constraint :cooking_records,
                         "CHAR_LENGTH(TRIM(name)) > 0",
                         name: "chk_cooking_records_name_present"

    add_check_constraint :person_tags,
                         "CHAR_LENGTH(TRIM(name)) > 0",
                         name: "chk_person_tags_name_present"
 
    unless check_constraint_exists?(:users, name: "chk_users_role")
      add_check_constraint :users,
        "role IN (0, 1)",
        name: "chk_users_role"
    end

    unless check_constraint_exists?(:meal_plans, name: "chk_meal_plans_meal_type")
      add_check_constraint :meal_plans,
        "meal_type IN (0, 1)",
        name: "chk_meal_plans_meal_type"
    end

    unless check_constraint_exists?(:meal_plans, name: "chk_meal_plans_migrated_at")
      add_check_constraint :meal_plans,
        "((migrated IS FALSE AND migrated_at IS NULL) OR (migrated IS TRUE AND migrated_at IS NOT NULL))",
        name: "chk_meal_plans_migrated_at"
    end
  end
end
