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

  test "index links every dish to the full edit page and preserves meal details" do
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
    assert_select "a.dish.meal-edit-trigger[href='#{edit_meal_plan_path(meal_plan)}'][data-turbo-frame='_top']", count: 2
    assert_select "a.dish.meal-edit-trigger[href='#{edit_meal_plan_path(meal_plan)}'] h3", { text: "カレー", count: 1 }
    assert_select "a.dish.meal-edit-trigger[href='#{edit_meal_plan_path(meal_plan)}'] h3", { text: "サラダ", count: 1 }
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
    assert_select ".error-panel", /今日以降を指定してください/
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
    assert_select "input[name='meal_date'][min='#{Date.current}']"
    assert_select "input[name='dishes[0][id]'][value='#{dish.id}']", 1
    assert_select "input[name='dishes[0][name]'][value='カレー']"
    assert_select "textarea[name='dishes[0][memo]']", /甘口/
    assert_select "input[name='dishes[0][ingredients][0][id]']", 1
    assert_select "input[name='dishes[0][ingredients][0][name]'][value='玉ねぎ']"
    assert_select "input[name='dishes[0][ingredients][0][add_to_shopping_list]'][checked='checked']", 1
    assert_select "input[name='dishes[0][ingredients][1][name]'][value='予約']"
    assert_select "input[name='dishes[0][ingredients][1][add_to_shopping_list]'][checked='checked']", count: 0
    assert_select "input[name='person_tag_ids[]'][value='#{tag.id}'][checked='checked']"
    assert_select "button", "料理を追加"
    assert_select "button", "食材を追加"
    assert_select "button[data-action='meal-plan-form#removeDish']", "削除"
    assert_select "button[data-turbo-confirm='本当に削除しますか？']", "献立を削除"
  end

  test "index keeps unregistered slots unlinked and omits the quick edit interface" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    meal_plan.plan_dishes.create!(name: "カレー", position: 0)

    get meal_plans_path

    assert_response :success
    assert_select "turbo-frame#meal_plans", count: 1
    assert_select ".meal-block .empty-state", { text: "未登録", count: 1 }
    assert_select "a", { text: "未登録", count: 0 }
    assert_select "[data-controller='meal-plan-edit']", count: 0
    assert_select "[data-action*='meal-plan-edit']", count: 0
    assert_select "[data-meal-plan-edit-target]", count: 0
    assert_select "input[name='quick_update']", count: 0
    assert_select ".meal-drawer-form", count: 0
    assert_select ".drawer-backdrop", count: 0
    assert_select ".edit-drawer", count: 0
    assert_select "template", count: 0
    assert_select "a", { text: "献立全体を編集", count: 0 }
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

  test "full update preserves unchanged records and appends new dishes after surviving positions" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    first = meal_plan.plan_dishes.create!(name: "カレー", memo: "そのまま", eating_out: true, position: 2)
    untouched = meal_plan.plan_dishes.create!(name: "味噌汁", memo: nil, eating_out: false, position: 5)
    removed = meal_plan.plan_dishes.create!(name: "削除対象", memo: "削除", position: 8)
    ingredient = first.dish_ingredients.create!(name: "玉ねぎ", add_to_shopping_list: true)
    removed_ingredient = removed.dish_ingredients.create!(name: "大根", add_to_shopping_list: true)
    item = @user.shopping_items.create!(
      dish_ingredient: ingredient,
      name: "玉ねぎ",
      manual: false,
      purchased: true,
      sort_order: 4321
    )
    removed_item = @user.shopping_items.create!(
      dish_ingredient: removed_ingredient,
      name: "大根",
      manual: false,
      purchased: true,
      sort_order: 8765
    )
    first_snapshot = first.attributes
    untouched_snapshot = untouched.attributes
    ingredient_snapshot = ingredient.attributes
    item_snapshot = item.attributes

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: Date.current.tomorrow,
      meal_type: "lunch",
      dishes: {
        "0" => {
          id: first.id,
          name: first.name,
          memo: first.memo,
          ingredients: {
            "0" => {
              id: ingredient.id,
              name: ingredient.name,
              add_to_shopping_list: "1"
            }
          }
        },
        "1" => {
          id: untouched.id,
          name: untouched.name,
          memo: "",
          ingredients: {}
        },
        "2" => {
          name: "新しい料理",
          memo: "追加",
          ingredients: {
            "0" => { name: "レタス", add_to_shopping_list: "0" }
          }
        },
        "3" => {
          name: "もう一品",
          memo: "",
          ingredients: {}
        }
      }
    )

    assert_redirected_to meal_plans_path
    assert_equal Date.current.tomorrow, meal_plan.reload.meal_date
    assert_equal first_snapshot, first.reload.attributes
    assert_equal untouched_snapshot, untouched.reload.attributes
    assert_equal ingredient_snapshot, ingredient.reload.attributes
    assert_equal item_snapshot, item.reload.attributes
    assert_equal [first.id], meal_plan.plan_dishes.where(id: first.id).pluck(:id)
    assert_not PlanDish.exists?(removed.id)
    assert_not DishIngredient.exists?(removed_ingredient.id)
    assert_not ShoppingItem.exists?(removed_item.id)
    assert_equal [["カレー", 2], ["味噌汁", 5], ["新しい料理", 6], ["もう一品", 7]], meal_plan.plan_dishes.ordered.pluck(:name, :position)
  end

  test "full update synchronizes every shopping item state without losing purchased metadata" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :dinner)
    dish = meal_plan.plan_dishes.create!(name: "鍋", position: 0)
    unchanged = dish.dish_ingredients.create!(name: "白菜", add_to_shopping_list: true)
    renamed = dish.dish_ingredients.create!(name: "豚こま", add_to_shopping_list: true)
    enabled = dish.dish_ingredients.create!(name: "豆腐", add_to_shopping_list: false)
    reused = dish.dish_ingredients.create!(name: "ねぎ", add_to_shopping_list: false)
    disabled = dish.dish_ingredients.create!(name: "春菊", add_to_shopping_list: true)
    deleted = dish.dish_ingredients.create!(name: "しめじ", add_to_shopping_list: true)
    omitted = dish.dish_ingredients.create!(name: "まいたけ", add_to_shopping_list: true)
    unchanged_item = @user.shopping_items.create!(dish_ingredient: unchanged, name: "白菜", manual: false, purchased: true, sort_order: 1100)
    renamed_item = @user.shopping_items.create!(dish_ingredient: renamed, name: "豚こま", manual: false, purchased: true, sort_order: 1200)
    reused_item = @user.shopping_items.create!(dish_ingredient: reused, name: "旧ねぎ", manual: false, purchased: true, sort_order: 1300)
    disabled_item = @user.shopping_items.create!(dish_ingredient: disabled, name: "春菊", manual: false, purchased: true, sort_order: 1400)
    deleted_item = @user.shopping_items.create!(dish_ingredient: deleted, name: "しめじ", manual: false, purchased: true, sort_order: 1500)
    omitted_item = @user.shopping_items.create!(dish_ingredient: omitted, name: "まいたけ", manual: false, purchased: true, sort_order: 1600)
    meal_plan_snapshot = meal_plan.attributes
    unchanged_snapshot = unchanged.attributes
    unchanged_item_snapshot = unchanged_item.attributes
    renamed_purchase_snapshot = renamed_item.attributes.slice("id", "purchased", "purchased_at", "sort_order", "manual", "dish_ingredient_id", "user_id", "created_at")
    reused_purchase_snapshot = reused_item.attributes.slice("id", "purchased", "purchased_at", "sort_order", "manual", "dish_ingredient_id", "user_id", "created_at")

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: meal_plan.meal_date,
      meal_type: meal_plan.meal_type,
      dishes: {
        "0" => {
          id: dish.id,
          name: dish.name,
          memo: dish.memo,
          ingredients: {
            "0" => { id: unchanged.id, name: " 白菜 ", add_to_shopping_list: "1" },
            "1" => { id: renamed.id, name: " 豚肉 ", add_to_shopping_list: "1" },
            "2" => { id: enabled.id, name: " 豆腐 ", add_to_shopping_list: "1" },
            "3" => { id: reused.id, name: " 青ねぎ ", add_to_shopping_list: "1" },
            "4" => { id: disabled.id, name: " 春菊 ", add_to_shopping_list: "0" },
            "5" => { id: deleted.id, name: "", add_to_shopping_list: "1" },
            "6" => { name: " えのき ", add_to_shopping_list: "1" },
            "7" => { name: " 予約品 ", add_to_shopping_list: "0" },
            "8" => { name: "   ", add_to_shopping_list: "1" }
          }
        }
      }
    )

    assert_redirected_to meal_plans_path
    assert_equal meal_plan_snapshot, meal_plan.reload.attributes
    assert_equal unchanged_snapshot, unchanged.reload.attributes
    assert_equal unchanged_item_snapshot, unchanged_item.reload.attributes
    assert_equal "豚肉", renamed.reload.name
    assert_equal "豚肉", renamed_item.reload.name
    assert_equal renamed_purchase_snapshot, renamed_item.attributes.slice(*renamed_purchase_snapshot.keys)
    assert enabled.reload.add_to_shopping_list?
    assert @user.shopping_items.exists?(dish_ingredient: enabled, name: "豆腐", purchased: false)
    assert reused.reload.add_to_shopping_list?
    assert_equal "青ねぎ", reused_item.reload.name
    assert_equal reused_purchase_snapshot, reused_item.attributes.slice(*reused_purchase_snapshot.keys)
    assert_not disabled.reload.add_to_shopping_list?
    assert_not ShoppingItem.exists?(disabled_item.id)
    assert_not DishIngredient.exists?(deleted.id)
    assert_not ShoppingItem.exists?(deleted_item.id)
    assert_not DishIngredient.exists?(omitted.id)
    assert_not ShoppingItem.exists?(omitted_item.id)
    assert @user.shopping_items.exists?(dish_ingredient: dish.dish_ingredients.find_by!(name: "えのき"), purchased: false)
    assert_not @user.shopping_items.exists?(dish_ingredient: dish.dish_ingredients.find_by!(name: "予約品"))
  end

  test "changing only a dish does not update its ingredients or shopping items" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    dish = meal_plan.plan_dishes.create!(name: "カレー", memo: "甘口", position: 4)
    ingredient = dish.dish_ingredients.create!(name: "玉ねぎ", add_to_shopping_list: true)
    item = @user.shopping_items.create!(dish_ingredient: ingredient, name: "玉ねぎ", manual: false, purchased: true, sort_order: 3000)
    ingredient_snapshot = ingredient.attributes
    item_snapshot = item.attributes

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: meal_plan.meal_date,
      meal_type: meal_plan.meal_type,
      dishes: {
        "0" => {
          id: dish.id,
          name: "シチュー",
          memo: dish.memo,
          ingredients: {
            "0" => { id: ingredient.id, name: ingredient.name, add_to_shopping_list: "1" }
          }
        }
      }
    )

    assert_redirected_to meal_plans_path
    assert_equal "シチュー", dish.reload.name
    assert_equal 4, dish.position
    assert_equal ingredient_snapshot, ingredient.reload.attributes
    assert_equal item_snapshot, item.reload.attributes
  end

  test "blank meal date is rejected with every related record and hidden id preserved" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :lunch)
    dish = meal_plan.plan_dishes.create!(name: "カレー", position: 0)
    ingredient = dish.dish_ingredients.create!(name: "玉ねぎ", add_to_shopping_list: true)
    @user.shopping_items.create!(dish_ingredient: ingredient, name: "玉ねぎ", manual: false)
    snapshot = meal_plan_graph_snapshot(meal_plan)

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: "",
      meal_type: meal_plan.meal_type,
      dishes: full_dish_params([dish])
    )

    assert_response :unprocessable_content
    assert_select ".error-panel", /日付を入力してください/
    assert_select "input[name='dishes[0][id]'][value='#{dish.id}']", 1
    assert_select "input[name='dishes[0][ingredients][0][id]'][value='#{ingredient.id}']", 1
    assert_equal snapshot, meal_plan_graph_snapshot(meal_plan)
  end

  test "blank meal type is rejected with every related record and hidden id preserved" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :dinner)
    dish = meal_plan.plan_dishes.create!(name: "鍋", position: 0)
    ingredient = dish.dish_ingredients.create!(name: "白菜", add_to_shopping_list: true)
    @user.shopping_items.create!(dish_ingredient: ingredient, name: "白菜", manual: false)
    snapshot = meal_plan_graph_snapshot(meal_plan)

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: meal_plan.meal_date,
      meal_type: "",
      dishes: full_dish_params([dish])
    )

    assert_response :unprocessable_content
    assert_select ".error-panel", /食事区分を入力してください/
    assert_select "input[name='dishes[0][id]'][value='#{dish.id}']", 1
    assert_select "input[name='dishes[0][ingredients][0][id]'][value='#{ingredient.id}']", 1
    assert_equal snapshot, meal_plan_graph_snapshot(meal_plan)
  end

  test "dish array parameters are rejected without changing related records" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    dish = meal_plan.plan_dishes.create!(name: "カレー", position: 0)
    ingredient = dish.dish_ingredients.create!(name: "玉ねぎ", add_to_shopping_list: true)
    @user.shopping_items.create!(dish_ingredient: ingredient, name: "玉ねぎ", manual: false)
    snapshot = meal_plan_graph_snapshot(meal_plan)

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: Date.current.tomorrow,
      meal_type: "dinner",
      dishes: [
        {
          id: dish.id,
          name: "改ざん",
          memo: "",
          ingredients: {
            "0" => { id: ingredient.id, name: "改ざん", add_to_shopping_list: "1" }
          }
        }
      ]
    )

    assert_response :unprocessable_content
    assert_select ".error-panel", /送信された料理または食材の形式が正しくありません/
    assert_equal snapshot, meal_plan_graph_snapshot(meal_plan)
  end

  test "ingredient array parameters are rejected without changing related records" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :dinner)
    dish = meal_plan.plan_dishes.create!(name: "鍋", position: 0)
    ingredient = dish.dish_ingredients.create!(name: "白菜", add_to_shopping_list: true)
    @user.shopping_items.create!(dish_ingredient: ingredient, name: "白菜", manual: false)
    snapshot = meal_plan_graph_snapshot(meal_plan)

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: Date.current.tomorrow,
      meal_type: "lunch",
      dishes: {
        "0" => {
          id: dish.id,
          name: "改ざん",
          memo: "",
          ingredients: [
            { id: ingredient.id, name: "改ざん", add_to_shopping_list: "1" }
          ]
        }
      }
    )

    assert_response :unprocessable_content
    assert_select ".error-panel", /送信された料理または食材の形式が正しくありません/
    assert_equal snapshot, meal_plan_graph_snapshot(meal_plan)
  end

  test "future meal date can be updated to today" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :lunch)
    dish = meal_plan.plan_dishes.create!(name: "カレー", position: 0)
    ingredient = dish.dish_ingredients.create!(name: "玉ねぎ")

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: Date.current,
      meal_type: meal_plan.meal_type,
      dishes: full_dish_params([dish])
    )

    assert_redirected_to meal_plans_path
    assert_equal Date.current, meal_plan.reload.meal_date
    assert_equal dish.id, meal_plan.plan_dishes.first.id
    assert_equal ingredient.id, dish.reload.dish_ingredients.first.id
  end

  test "repeating the same full update does not touch records or duplicate shopping items" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :dinner)
    dish = meal_plan.plan_dishes.create!(name: "鍋", memo: nil, position: 0)
    ingredient = dish.dish_ingredients.create!(name: "豆腐", add_to_shopping_list: false)
    request_params = meal_plan_params(
      meal_date: meal_plan.meal_date,
      meal_type: meal_plan.meal_type,
      dishes: {
        "0" => {
          id: dish.id,
          name: dish.name,
          memo: "",
          ingredients: {
            "0" => { id: ingredient.id, name: ingredient.name, add_to_shopping_list: "1" }
          }
        }
      }
    )

    patch meal_plan_path(meal_plan), params: request_params.deep_dup
    assert_redirected_to meal_plans_path
    assert_equal 1, @user.shopping_items.where(dish_ingredient: ingredient).count
    first_update_snapshot = meal_plan_graph_snapshot(meal_plan)

    patch meal_plan_path(meal_plan), params: request_params.deep_dup

    assert_redirected_to meal_plans_path
    assert_equal first_update_snapshot, meal_plan_graph_snapshot(meal_plan)
    assert_equal 1, @user.shopping_items.where(dish_ingredient: ingredient).count
  end

  test "unchanged person tags keep their join ids attributes and timestamps" do
    tag = @user.person_tags.create!(name: "家族")
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    meal_plan.person_tags << tag
    join = MealPlanPersonTag.find_by!(meal_plan: meal_plan, person_tag: tag)
    dish = meal_plan.plan_dishes.create!(name: "カレー", position: 0)
    ingredient = dish.dish_ingredients.create!(name: "玉ねぎ", add_to_shopping_list: true)
    @user.shopping_items.create!(dish_ingredient: ingredient, name: "玉ねぎ", manual: false)
    graph_snapshot = meal_plan_graph_snapshot(meal_plan)
    join_snapshot = join.attributes

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: meal_plan.meal_date,
      meal_type: meal_plan.meal_type,
      person_tag_ids: [tag.id],
      dishes: full_dish_params([dish])
    )

    assert_redirected_to meal_plans_path
    assert_equal graph_snapshot, meal_plan_graph_snapshot(meal_plan)
    assert_equal join_snapshot, join.reload.attributes
  end

  test "a late shopping item failure rolls back the entire full update graph" do
    old_tag = @user.person_tags.create!(name: "家族")
    new_tag = @user.person_tags.create!(name: "友人")
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    meal_plan.person_tags << old_tag
    dish = meal_plan.plan_dishes.create!(name: "カレー", memo: "甘口", position: 0)
    ingredient = dish.dish_ingredients.create!(name: "玉ねぎ", add_to_shopping_list: true)
    item = @user.shopping_items.create!(
      dish_ingredient: ingredient,
      name: "玉ねぎ",
      manual: false,
      purchased: true,
      sort_order: 4321
    )
    @user.cooking_records.create!(
      source_meal_plan: meal_plan,
      source_plan_dish: dish,
      name: dish.name,
      cooked_on: meal_plan.meal_date,
      meal_type: meal_plan.meal_type
    )
    snapshot = meal_plan_graph_snapshot(meal_plan)
    person_tag_snapshot = PersonTag.where(id: [old_tag.id, new_tag.id]).order(:id).map(&:attributes)
    original_save = ShoppingItem.instance_method(:save!)
    had_own_save = ShoppingItem.instance_methods(false).include?(:save!)
    fault_key = :meal_plan_full_update_shopping_item_failure

    ShoppingItem.send(:define_method, :save!) do |**options|
      if Thread.current[fault_key] && id == item.id
        errors.add(:name, "の同期に失敗しました")
        raise ActiveRecord::RecordInvalid, self
      end

      original_save.bind_call(self, **options)
    end

    begin
      Thread.current[fault_key] = true
      patch meal_plan_path(meal_plan), params: meal_plan_params(
        meal_date: Date.current.tomorrow,
        meal_type: "dinner",
        person_tag_ids: [new_tag.id],
        dishes: {
          "0" => {
            id: dish.id,
            name: "シチュー",
            memo: "変更",
            ingredients: {
              "0" => {
                id: ingredient.id,
                name: "新玉ねぎ",
                add_to_shopping_list: "1"
              }
            }
          }
        }
      )

      assert_response :unprocessable_content
      assert_select ".error-panel", /同期に失敗しました/
      assert_select "input[name='dishes[0][id]'][value='#{dish.id}']", 1
      assert_select "input[name='dishes[0][ingredients][0][id]'][value='#{ingredient.id}']", 1
    ensure
      Thread.current[fault_key] = nil
      if had_own_save
        ShoppingItem.send(:define_method, :save!, original_save)
      else
        ShoppingItem.send(:remove_method, :save!)
      end
    end

    assert_equal snapshot, meal_plan_graph_snapshot(meal_plan)
    assert_equal person_tag_snapshot, PersonTag.where(id: [old_tag.id, new_tag.id]).order(:id).map(&:attributes)
  end

  test "full update can delete first middle and last dishes but rejects deleting the final dish" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    dishes = 4.times.map { |index| meal_plan.plan_dishes.create!(name: "料理#{index + 1}", position: index) }

    [dishes[1], dishes[0], dishes[3]].each do |removed|
      remaining = meal_plan.plan_dishes.where.not(id: removed.id).ordered.to_a
      patch meal_plan_path(meal_plan), params: meal_plan_params(
        meal_date: meal_plan.meal_date,
        meal_type: meal_plan.meal_type,
        dishes: full_dish_params(remaining)
      )

      assert_redirected_to meal_plans_path
      assert_not PlanDish.exists?(removed.id)
      meal_plan.reload
    end

    final_dish = meal_plan.plan_dishes.first
    final_snapshot = final_dish.attributes
    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: meal_plan.meal_date,
      meal_type: meal_plan.meal_type,
      dishes: {}
    )

    assert_response :unprocessable_content
    assert_select ".error-panel", /料理を1件以上入力してください/
    assert_equal final_snapshot, final_dish.reload.attributes
  end

  test "past duplicate and blank dish updates are rejected without mutation" do
    date = Date.current.tomorrow
    meal_plan = @user.meal_plans.create!(meal_date: date, meal_type: :lunch)
    dish = meal_plan.plan_dishes.create!(name: "カレー", position: 0)
    @user.meal_plans.create!(meal_date: date, meal_type: :dinner)
    snapshot = meal_plan_graph_snapshot(meal_plan)

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: Date.current.yesterday,
      meal_type: "lunch",
      dishes: full_dish_params([dish])
    )
    assert_response :unprocessable_content
    assert_select ".error-panel", /今日以降/
    assert_equal snapshot, meal_plan_graph_snapshot(meal_plan)

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: date,
      meal_type: "dinner",
      dishes: full_dish_params([dish])
    )
    assert_response :unprocessable_content
    assert_equal snapshot, meal_plan_graph_snapshot(meal_plan)

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: date,
      meal_type: "lunch",
      dishes: {
        "0" => { id: dish.id, name: " ", memo: "変更", ingredients: {} }
      }
    )
    assert_response :unprocessable_content
    assert_select ".error-panel", /料理名を入力してください/
    assert_equal snapshot, meal_plan_graph_snapshot(meal_plan)
  end

  test "edit and full update hide other owners and migrated meal plans" do
    other_plan = @other_user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    other_dish = other_plan.plan_dishes.create!(name: "他人の料理", position: 0)
    migrated = @user.meal_plans.create!(
      meal_date: Date.current.yesterday,
      meal_type: :dinner,
      migrated: true,
      migrated_at: Time.current
    )
    migrated_dish = migrated.plan_dishes.create!(name: "移行済み", position: 0)

    get edit_meal_plan_path(other_plan)
    assert_response :not_found
    patch meal_plan_path(other_plan), params: meal_plan_params(
      meal_date: other_plan.meal_date,
      meal_type: other_plan.meal_type,
      dishes: full_dish_params([other_dish])
    )
    assert_response :not_found

    get edit_meal_plan_path(migrated)
    assert_response :not_found
    patch meal_plan_path(migrated), params: meal_plan_params(
      meal_date: migrated.meal_date,
      meal_type: migrated.meal_type,
      dishes: full_dish_params([migrated_dish])
    )
    assert_response :not_found

    assert_equal "他人の料理", other_dish.reload.name
    assert_equal "移行済み", migrated_dish.reload.name
  end

  test "tampered nested ids return not found and roll back all changes" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    dish = meal_plan.plan_dishes.create!(name: "カレー", position: 0)
    ingredient = dish.dish_ingredients.create!(name: "玉ねぎ", add_to_shopping_list: true)
    second_dish = meal_plan.plan_dishes.create!(name: "サラダ", position: 1)
    second_ingredient = second_dish.dish_ingredients.create!(name: "レタス", add_to_shopping_list: true)
    @user.shopping_items.create!(dish_ingredient: ingredient, name: "玉ねぎ", manual: false, purchased: true)
    @user.shopping_items.create!(dish_ingredient: second_ingredient, name: "レタス", manual: false)
    tag = @user.person_tags.create!(name: "家族")
    meal_plan.person_tags << tag
    other_plan = @other_user.meal_plans.create!(meal_date: Date.current, meal_type: :dinner)
    other_dish = other_plan.plan_dishes.create!(name: "他人", position: 0)
    other_ingredient = other_dish.dish_ingredients.create!(name: "秘密")
    scoped_plan = @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :dinner)
    scoped_dish = scoped_plan.plan_dishes.create!(name: "別の献立", position: 0)
    scoped_ingredient = scoped_dish.dish_ingredients.create!(name: "別の食材")
    snapshot = meal_plan_graph_snapshot(meal_plan)

    [
      {
        "0" => { id: PlanDish.maximum(:id).to_i + 10_000, name: "不存在", memo: "", ingredients: {} },
        "1" => full_dish_params([second_dish]).fetch("0")
      },
      {
        "0" => { id: scoped_dish.id, name: "別献立から改ざん", memo: "", ingredients: {} },
        "1" => full_dish_params([second_dish]).fetch("0")
      },
      {
        "0" => { id: other_dish.id, name: "改ざん", memo: "", ingredients: {} },
        "1" => full_dish_params([second_dish]).fetch("0")
      },
      {
        "0" => {
          id: dish.id,
          name: "変更",
          memo: "",
          ingredients: {
            "0" => { id: scoped_ingredient.id, name: "別献立から改ざん", add_to_shopping_list: "1" }
          }
        },
        "1" => full_dish_params([second_dish]).fetch("0")
      },
      {
        "0" => {
          id: dish.id,
          name: "変更",
          memo: "",
          ingredients: {
            "0" => { id: other_ingredient.id, name: "改ざん", add_to_shopping_list: "1" }
          }
        },
        "1" => full_dish_params([second_dish]).fetch("0")
      },
      {
        "0" => {
          id: dish.id,
          name: "変更",
          memo: "",
          ingredients: {
            "0" => { id: second_ingredient.id, name: "付け替え", add_to_shopping_list: "1" }
          }
        },
        "1" => {
          id: second_dish.id,
          name: second_dish.name,
          memo: second_dish.memo,
          ingredients: {}
        }
      },
      {
        "0" => {
          id: dish.id,
          name: "変更",
          memo: "",
          ingredients: {
            "0" => { id: DishIngredient.maximum(:id).to_i + 10_000, name: "不存在", add_to_shopping_list: "1" }
          }
        },
        "1" => full_dish_params([second_dish]).fetch("0")
      }
    ].each_with_index do |dishes, index|
      patch meal_plan_path(meal_plan), params: meal_plan_params(
        meal_date: Date.current.tomorrow,
        meal_type: meal_plan.meal_type,
        dishes: dishes
      )
      assert_response :not_found, "tampered nested id case #{index + 1}"
      assert_equal snapshot, meal_plan_graph_snapshot(meal_plan)
    end
  end

  test "duplicate nested ids return unprocessable content and retain hidden ids" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :dinner)
    dish = meal_plan.plan_dishes.create!(name: "鍋", position: 0)
    ingredient = dish.dish_ingredients.create!(name: "白菜")
    snapshot = dish.attributes

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: meal_plan.meal_date,
      meal_type: meal_plan.meal_type,
      dishes: {
        "0" => {
          id: dish.id,
          name: "鍋A",
          memo: "",
          ingredients: {
            "0" => { id: ingredient.id, name: "白菜A", add_to_shopping_list: "1" },
            "1" => { id: ingredient.id, name: "白菜B", add_to_shopping_list: "1" }
          }
        },
        "1" => {
          id: dish.id,
          name: "鍋B",
          memo: "",
          ingredients: {}
        }
      }
    )

    assert_response :unprocessable_content
    assert_select ".error-panel", /同じ料理が重複/
    assert_select "input[name='dishes[0][id]'][value='#{dish.id}']", 1
    assert_select "input[name='dishes[1][id]'][value='#{dish.id}']", 1
    assert_select "input[name='dishes[0][ingredients][0][id]'][value='#{ingredient.id}']", 1
    assert_select "input[name='dishes[0][ingredients][1][id]'][value='#{ingredient.id}']", 1
    assert_equal snapshot, dish.reload.attributes
    assert_equal "白菜", ingredient.reload.name

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: meal_plan.meal_date,
      meal_type: meal_plan.meal_type,
      dishes: {
        "0" => {
          id: dish.id,
          name: "鍋",
          memo: "",
          ingredients: {
            "0" => { id: ingredient.id, name: "白菜A", add_to_shopping_list: "1" },
            "1" => { id: ingredient.id, name: "白菜B", add_to_shopping_list: "1" }
          }
        }
      }
    )

    assert_response :unprocessable_content
    assert_select ".error-panel", /同じ食材が重複/
    assert_select "input[name='dishes[0][id]'][value='#{dish.id}']", 1
    assert_select "input[name='dishes[0][ingredients][0][id]'][value='#{ingredient.id}']", 1
    assert_select "input[name='dishes[0][ingredients][1][id]'][value='#{ingredient.id}']", 1
    assert_equal snapshot, dish.reload.attributes
    assert_equal "白菜", ingredient.reload.name
  end

  test "deleting a dish with a cooking record rejects every mutation and keeps the record" do
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    kept = meal_plan.plan_dishes.create!(name: "カレー", position: 0)
    protected_dish = meal_plan.plan_dishes.create!(name: "サラダ", position: 1)
    protected_ingredient = protected_dish.dish_ingredients.create!(name: "レタス", add_to_shopping_list: true)
    protected_item = @user.shopping_items.create!(dish_ingredient: protected_ingredient, name: "レタス", manual: false, purchased: true)
    cooking_record = @user.cooking_records.create!(
      source_meal_plan: meal_plan,
      source_plan_dish: protected_dish,
      name: protected_dish.name,
      cooked_on: meal_plan.meal_date,
      meal_type: meal_plan.meal_type
    )
    snapshots = [meal_plan, kept, protected_dish, protected_ingredient, protected_item, cooking_record].to_h do |record|
      [record.class.name + record.id.to_s, record.attributes]
    end

    patch meal_plan_path(meal_plan), params: meal_plan_params(
      meal_date: Date.current.tomorrow,
      meal_type: "dinner",
      dishes: {
        "0" => { id: kept.id, name: "変更", memo: "", ingredients: {} }
      }
    )

    assert_response :unprocessable_content
    assert_select ".error-panel", /調理記録がある料理は削除できません/
    assert_select ".error-panel", /画面を再読み込みしてください/
    [meal_plan, kept, protected_dish, protected_ingredient, protected_item, cooking_record].each do |record|
      assert_equal snapshots.fetch(record.class.name + record.id.to_s), record.reload.attributes
    end
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

  def meal_plan_graph_snapshot(meal_plan)
    dish_ids = PlanDish.where(meal_plan_id: meal_plan.id).order(:id).pluck(:id)
    ingredient_ids = DishIngredient.where(plan_dish_id: dish_ids).order(:id).pluck(:id)
    joins = MealPlanPersonTag.where(meal_plan_id: meal_plan.id).order(:id).to_a
    person_tag_ids = joins.map(&:person_tag_id)

    {
      meal_plan: MealPlan.find(meal_plan.id).attributes,
      plan_dishes: PlanDish.where(id: dish_ids).order(:id).map(&:attributes),
      dish_ingredients: DishIngredient.where(id: ingredient_ids).order(:id).map(&:attributes),
      shopping_items: ShoppingItem.where(dish_ingredient_id: ingredient_ids).order(:id).map(&:attributes),
      meal_plan_person_tags: joins.map(&:attributes),
      person_tags: PersonTag.where(id: person_tag_ids).order(:id).map(&:attributes),
      cooking_records: CookingRecord.where(source_meal_plan_id: meal_plan.id)
                                    .or(CookingRecord.where(source_plan_dish_id: dish_ids))
                                    .order(:id)
                                    .map(&:attributes)
    }
  end

  def full_dish_params(dishes)
    Array(dishes).each_with_index.to_h do |dish, index|
      ingredients = dish.dish_ingredients.order(:id).each_with_index.to_h do |ingredient, ingredient_index|
        [
          ingredient_index.to_s,
          {
            id: ingredient.id,
            name: ingredient.name,
            add_to_shopping_list: ingredient.add_to_shopping_list? ? "1" : "0"
          }
        ]
      end

      [
        index.to_s,
        {
          id: dish.id,
          name: dish.name,
          memo: dish.memo,
          ingredients: ingredients
        }
      ]
    end
  end

  def meal_plan_params(overrides)
    {
      meal_date: overrides[:meal_date],
      meal_type: overrides[:meal_type],
      person_tag_ids: overrides.fetch(:person_tag_ids, []),
      dishes: overrides.fetch(:dishes, {})
    }
  end
end
