require "test_helper"

class MealPlansTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "meal-plans@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    @other_user = User.create!(
      email: "other-meal-plans@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    post login_path, params: { email: @user.email, password: "password1" }
  end

  test "index shows active today and future plans by date with lunch and dinner frames" do
    today_lunch = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    today_lunch.plan_dishes.create!(name: "カレー", position: 0)
    today_lunch.plan_dishes.create!(name: "サラダ", position: 1)

    tomorrow_dinner = @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :dinner)
    tomorrow_dinner.plan_dishes.create!(name: "焼き魚", position: 0)

    old_plan = @user.meal_plans.create!(
      meal_date: Date.current.yesterday,
      meal_type: :dinner,
      migrated: true,
      migrated_at: Time.current
    )
    old_plan.plan_dishes.create!(name: "昨日の料理", position: 0)

    @other_user.meal_plans.create!(meal_date: Date.current, meal_type: :dinner)
               .plan_dishes.create!(name: "他人の料理", position: 0)

    get meal_plans_path

    assert_response :success
    assert_select ".meal-label", "昼食"
    assert_select ".meal-label", "夕食"
    assert_select ".summary-card", 0
    assert_select ".create-button", 0
    assert_select ".edit-link", 0
    assert_select ".dish-icon", "🍛"
    assert_select "h3", /カレー/
    assert_select "h3", /サラダ/
    assert_select "h3", /焼き魚/
    assert_select "body", { text: /昨日の料理/, count: 0 }
    assert_select "body", { text: /他人の料理/, count: 0 }
    assert_select "body", { text: /朝食/, count: 0 }
  end

  test "index shows person tags next to meal type and quick edit drawer" do
    tag = @user.person_tags.create!(name: "家族")
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    meal_plan.person_tags << tag
    curry = meal_plan.plan_dishes.create!(name: "カレー", memo: "甘口", position: 0)
    curry.dish_ingredients.create!(name: "玉ねぎ")
    curry.dish_ingredients.create!(name: "にんじん")
    salad = meal_plan.plan_dishes.create!(name: "サラダ", memo: "別枠", position: 1)

    get meal_plans_path

    assert_response :success
    assert_select ".meal-tag-line", "家族"
    assert_select ".dish-icon", "🍛"
    assert_select ".meal-edit-trigger h3", "カレー"
    assert_select ".meal-dish-detail", /玉ねぎ, にんじん/
    assert_select ".meal-dish-detail", /甘口/
    assert_select ".edit-drawer"

    document = Nokogiri::HTML(response.body)
    curry_template = document.at_css("template[data-dish-id='#{curry.id}']").inner_html
    assert_includes curry_template, "dishes[#{curry.id}][name]"
    assert_includes curry_template, "献立名"
    assert_includes curry_template, "食材"
    assert_includes curry_template, "add_to_shopping_list"
    assert_includes curry_template, "買い物リストに追加"
    assert_includes curry_template, "メモ"
    assert_not_includes curry_template, "dishes[#{salad.id}][name]"
  end

  test "user creates a meal plan with multiple dishes ingredients person tags and shopping items" do
    tag = @user.person_tags.create!(name: "家族")
    other_tag = @other_user.person_tags.create!(name: "他人")

    assert_difference -> { @user.meal_plans.count }, 1 do
      assert_difference -> { PlanDish.count }, 2 do
        assert_difference -> { DishIngredient.count }, 3 do
          assert_difference -> { @user.shopping_items.count }, 3 do
            post meal_plans_path, params: meal_plan_params(
              meal_date: Date.current.tomorrow,
              meal_type: "lunch",
              person_tag_ids: [tag.id, other_tag.id],
              dishes: {
                "0" => {
                  name: "カレー",
                  memo: "甘口",
                  ingredients: {
                    "0" => { name: "玉ねぎ", add_to_shopping_list: "1" },
                    "1" => { name: "にんじん", add_to_shopping_list: "1" }
                  }
                },
                "1" => {
                  name: "サラダ",
                  memo: "",
                  ingredients: {
                    "0" => { name: "レタス", add_to_shopping_list: "1" }
                  }
                }
              }
            )
          end
        end
      end
    end

    assert_redirected_to meal_plans_path
    meal_plan = @user.meal_plans.order(:created_at).last
    assert_equal "lunch", meal_plan.meal_type
    assert_equal ["カレー", "サラダ"], meal_plan.plan_dishes.ordered.pluck(:name)
    assert_equal [false, false], meal_plan.plan_dishes.ordered.map(&:eating_out?)
    assert_equal ["家族"], meal_plan.person_tags.pluck(:name)
    assert_equal ["にんじん", "レタス", "玉ねぎ"].sort, @user.shopping_items.pluck(:name).sort
  end

  test "user cannot create a meal plan in the past" do
    assert_no_difference -> { @user.meal_plans.count } do
      post meal_plans_path, params: meal_plan_params(
        meal_date: Date.current.yesterday,
        meal_type: "lunch",
        dishes: {
          "0" => {
            name: "昨日の献立",
            memo: "",
            ingredients: {
              "0" => { name: "玉ねぎ", add_to_shopping_list: "1" }
            }
          }
        }
      )
    end

    assert_response :unprocessable_content
    assert_select ".error-panel", /日付は今日以降を指定してください/
  end

  test "new meal plan form starts with one dish and three ingredient fields" do
    get new_meal_plan_path

    assert_response :success
    assert_select "form[autocomplete='off'][data-controller='meal-plan-form']"
    assert_select "section.dish-card[data-dish-index='0']", 1
    assert_select "input[name='meal_date'][autocomplete='off'][min='#{Date.current}']", 1
    assert_select "input[name='dishes[0][name]'][autocomplete='off']", 1
    assert_select "input[name='dishes[1][name]']", 0
    assert_select "input[name='dishes[0][ingredients][0][name]'][autocomplete='off']", 1
    assert_select "input[name='dishes[0][ingredients][1][name]'][autocomplete='off']", 1
    assert_select "input[name='dishes[0][ingredients][2][name]'][autocomplete='off']", 1
    assert_select "textarea[name='dishes[0][memo]'][autocomplete='off']", 1
    assert_select "input[name='dishes[0][ingredients][0][add_to_shopping_list]']", 2
    assert_select "button", "料理を追加"
    assert_select "button", "食材を追加"
    assert_select ".ingredient-shopping-heading", "買い物"
    assert_select "section.dish-card[data-dish-index='0'] .ingredient-field .danger-icon-button", 3
    assert_select "input[placeholder]", 0
    assert_select "textarea[placeholder]", 0
    assert_select "body", { text: /外食として記録/, count: 0 }
  end

  test "edit meal plan form shows dishes ingredients shopping checks and delete confirmation" do
    tag = @user.person_tags.create!(name: "家族")
    meal_plan = @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :dinner)
    meal_plan.person_tags << tag
    dish = meal_plan.plan_dishes.create!(name: "カレー", memo: "甘口", position: 0)
    dish.dish_ingredients.create!(name: "玉ねぎ", add_to_shopping_list: true)
    dish.dish_ingredients.create!(name: "予約", add_to_shopping_list: false)

    get edit_meal_plan_path(meal_plan)

    assert_response :success
    assert_select "[data-controller='meal-plan-form']"
    assert_select "input[name='dishes[0][name]'][value='カレー']"
    assert_select "textarea[name='dishes[0][memo]']", /甘口/
    assert_select "input[name='dishes[0][ingredients][0][name]'][value='玉ねぎ']"
    assert_select "input[name='dishes[0][ingredients][0][add_to_shopping_list]'][checked='checked']", 1
    assert_select "input[name='dishes[0][ingredients][1][name]'][value='予約']"
    assert_select "input[name='dishes[0][ingredients][1][add_to_shopping_list]'][checked='checked']", count: 0
    assert_select "input[name='person_tag_ids[]'][value='#{tag.id}'][checked='checked']"
    assert_select "button", "料理を追加"
    assert_select "button", "食材を追加"
    assert_select "button[data-turbo-confirm='本当に削除しますか？']", "献立を削除"
  end

  test "user updates dishes ingredients person tags and shopping items" do
    old_tag = @user.person_tags.create!(name: "家族")
    new_tag = @user.person_tags.create!(name: "友人")
    meal_plan = @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :lunch)
    meal_plan.person_tags << old_tag
    dish = meal_plan.plan_dishes.create!(name: "カレー", memo: "甘口", position: 0)
    ingredient = dish.dish_ingredients.create!(name: "玉ねぎ", add_to_shopping_list: true)
    @user.shopping_items.create!(dish_ingredient: ingredient, name: "玉ねぎ", manual: false)

    assert_no_difference -> { @user.meal_plans.count } do
      patch meal_plan_path(meal_plan), params: meal_plan_params(
        meal_date: Date.current.tomorrow,
        meal_type: "dinner",
        person_tag_ids: [new_tag.id],
        dishes: {
          "0" => {
            name: "シチュー",
            memo: "牛乳多め",
            ingredients: {
              "0" => { name: "じゃがいも", add_to_shopping_list: "1" },
              "1" => { name: "牛乳", add_to_shopping_list: "0" }
            }
          },
          "1" => {
            name: "サラダ",
            memo: "",
            ingredients: {
              "0" => { name: "レタス", add_to_shopping_list: "1" }
            }
          }
        }
      )
    end

    assert_redirected_to meal_plans_path
    meal_plan.reload
    assert_equal "dinner", meal_plan.meal_type
    assert_equal ["シチュー", "サラダ"], meal_plan.plan_dishes.ordered.pluck(:name)
    assert_equal ["友人"], meal_plan.person_tags.pluck(:name)
    assert_equal ["じゃがいも", "レタス"].sort, @user.shopping_items.pluck(:name).sort
    assert_equal ["じゃがいも", "牛乳", "レタス"].sort, DishIngredient.joins(:plan_dish).where(plan_dishes: { meal_plan_id: meal_plan.id }).pluck(:name).sort
  end

  test "user quick updates meal plan dishes and person tags with turbo stream" do
    old_tag = @user.person_tags.create!(name: "家族")
    new_tag = @user.person_tags.create!(name: "友人")
    meal_plan = @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :lunch)
    meal_plan.person_tags << old_tag
    dish = meal_plan.plan_dishes.create!(name: "カレー", memo: "甘口", position: 0)

    patch meal_plan_path(meal_plan, format: :turbo_stream), params: {
      quick_update: "1",
      person_tag_ids: [new_tag.id],
      dishes: {
        dish.id.to_s => { name: "シチュー", memo: "牛乳多め" }
      }
    }

    assert_response :success
    assert_equal "シチュー", dish.reload.name
    assert_equal "牛乳多め", dish.memo
    assert_equal ["友人"], meal_plan.reload.person_tags.pluck(:name)
    assert_includes response.body, "献立を更新しました"
    assert_includes response.body, "シチュー"
  end

  test "quick update edits deletes and adds ingredients with scoped shopping items" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    dish = meal_plan.plan_dishes.create!(name: "カレー", memo: "甘口", position: 0)
    onion = dish.dish_ingredients.create!(name: "たまねぎ", add_to_shopping_list: true)
    carrot = dish.dish_ingredients.create!(name: "にんじん", add_to_shopping_list: true)
    daikon = dish.dish_ingredients.create!(name: "大根", add_to_shopping_list: false)
    onion_item = @user.shopping_items.create!(dish_ingredient: onion, name: "たまねぎ", manual: false)
    carrot_item = @user.shopping_items.create!(dish_ingredient: carrot, name: "にんじん", manual: false)

    other_plan = @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :dinner)
    other_dish = other_plan.plan_dishes.create!(name: "別メニュー", position: 0)
    other_onion = other_dish.dish_ingredients.create!(name: "たまねぎ", add_to_shopping_list: true)
    other_onion_item = @user.shopping_items.create!(dish_ingredient: other_onion, name: "たまねぎ", manual: false)

    assert_difference -> { dish.dish_ingredients.count }, 0 do
      assert_difference -> { @user.shopping_items.count }, 0 do
        patch meal_plan_path(meal_plan, format: :turbo_stream), params: {
          quick_update: "1",
          dishes: {
            dish.id.to_s => { name: "カレー", memo: "甘口" }
          },
          ingredients: {
            "existing_#{onion.id}" => { id: onion.id, name: "玉ねぎ", add_to_shopping_list: "1", delete: "0" },
            "existing_#{carrot.id}" => { id: carrot.id, name: "にんじん", add_to_shopping_list: "1", delete: "1" },
            "existing_#{daikon.id}" => { id: daikon.id, name: "大根", add_to_shopping_list: "1", delete: "0" },
            "new_1" => { dish_id: dish.id, name: "じゃがいも", add_to_shopping_list: "0" }
          }
        }
      end
    end

    assert_response :success
    assert_equal "玉ねぎ", onion.reload.name
    assert_equal "玉ねぎ", onion_item.reload.name
    assert daikon.reload.add_to_shopping_list?
    assert @user.shopping_items.exists?(dish_ingredient: daikon, name: "大根")
    assert_not DishIngredient.exists?(carrot.id)
    assert_not ShoppingItem.exists?(carrot_item.id)
    assert_equal "たまねぎ", other_onion.reload.name
    assert_equal "たまねぎ", other_onion_item.reload.name
    assert_not @user.shopping_items.exists?(dish_ingredient: dish.dish_ingredients.find_by!(name: "じゃがいも"))
  end

  test "invalid update does not leave partial related data" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :lunch)
    meal_plan.plan_dishes.create!(name: "カレー", position: 0)

    assert_no_difference -> { meal_plan.plan_dishes.count } do
      assert_no_difference -> { DishIngredient.count } do
        patch meal_plan_path(meal_plan), params: meal_plan_params(
          meal_date: Date.current.tomorrow,
          meal_type: "lunch",
          dishes: {
            "0" => {
              name: "",
              memo: "名前なし",
              ingredients: {
                "0" => { name: "玉ねぎ", add_to_shopping_list: "1" }
              }
            }
          }
        )
      end
    end

    assert_response :unprocessable_content
    assert_equal ["カレー"], meal_plan.reload.plan_dishes.pluck(:name)
  end

  test "user deletes own meal plan with related records" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :lunch)
    dish = meal_plan.plan_dishes.create!(name: "カレー", position: 0)
    ingredient = dish.dish_ingredients.create!(name: "玉ねぎ")
    @user.shopping_items.create!(dish_ingredient: ingredient, name: "玉ねぎ", manual: false)

    assert_difference -> { @user.meal_plans.count }, -1 do
      delete meal_plan_path(meal_plan)
    end

    assert_redirected_to meal_plans_path
    assert_not PlanDish.exists?(dish.id)
    assert_not DishIngredient.exists?(ingredient.id)
    assert_equal 0, @user.shopping_items.count
  end

  test "user cannot create meal plan without required fields or dishes" do
    assert_no_difference -> { MealPlan.count } do
      post meal_plans_path, params: meal_plan_params(
        meal_date: "",
        meal_type: "",
        dishes: {
          "0" => {
            name: "",
            memo: "",
            ingredients: {
              "0" => { name: "", add_to_shopping_list: "1" }
            }
          }
        }
      )
    end

    assert_response :unprocessable_content
    assert_select ".error-panel"
  end

  test "duplicate meal plan does not leave partial related data" do
    @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :lunch)

    assert_no_difference -> { MealPlan.count } do
      assert_no_difference -> { PlanDish.count } do
        assert_no_difference -> { DishIngredient.count } do
          assert_no_difference -> { ShoppingItem.count } do
            post meal_plans_path, params: meal_plan_params(
              meal_date: Date.current.tomorrow,
              meal_type: "lunch",
              dishes: {
                "0" => {
                  name: "カレー",
                  memo: "",
                  ingredients: {
                    "0" => { name: "玉ねぎ", add_to_shopping_list: "1" }
                  }
                }
              }
            )
          end
        end
      end
    end

    assert_response :unprocessable_content
    assert_select ".error-panel"
  end

  test "lunch and dinner can be created separately on the same date" do
    date = Date.current.tomorrow

    post meal_plans_path, params: meal_plan_params(
      meal_date: date,
      meal_type: "lunch",
      dishes: { "0" => { name: "昼の料理", memo: "", ingredients: {} } }
    )
    assert_redirected_to meal_plans_path

    post meal_plans_path, params: meal_plan_params(
      meal_date: date,
      meal_type: "dinner",
      dishes: { "0" => { name: "夜の料理", memo: "", ingredients: {} } }
    )
    assert_redirected_to meal_plans_path

    assert_equal 2, @user.meal_plans.where(meal_date: date).count
  end

  test "ingredients can be saved without adding shopping items" do
    assert_difference -> { DishIngredient.count }, 1 do
      assert_no_difference -> { ShoppingItem.count } do
        post meal_plans_path, params: meal_plan_params(
          meal_date: Date.current.tomorrow,
          meal_type: "dinner",
          dishes: {
            "0" => {
              name: "買い物不要の料理",
              memo: "",
              ingredients: {
                "0" => { name: "予約", add_to_shopping_list: "0" }
              }
            }
          }
        )
      end
    end

    assert_redirected_to meal_plans_path
    ingredient = DishIngredient.order(:created_at).last
    assert_equal "予約", ingredient.name
    assert_not ingredient.add_to_shopping_list?
  end

  private

  def meal_plan_params(overrides)
    {
      meal_date: overrides[:meal_date],
      meal_type: overrides[:meal_type],
      person_tag_ids: overrides.fetch(:person_tag_ids, []),
      dishes: overrides.fetch(:dishes, {})
    }
  end
end
