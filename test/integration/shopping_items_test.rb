require "test_helper"

class ShoppingItemsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "shopping@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    @other_user = User.create!(
      email: "other-shopping@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    post login_path, params: { email: @user.email, password: "password1" }
  end

  test "meal plan and manual shopping items are shown together as unpurchased rows" do
    lunch = @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :lunch)
    curry = lunch.plan_dishes.create!(name: "カレー", position: 0)
    salad = lunch.plan_dishes.create!(name: "サラダ", position: 1)
    onion = curry.dish_ingredients.create!(name: "玉ねぎ")
    onion2 = salad.dish_ingredients.create!(name: " 玉ねぎ ")
    milk = curry.dish_ingredients.create!(name: "牛乳")
    @user.shopping_items.create!(dish_ingredient: onion, name: "玉ねぎ", manual: false)
    @user.shopping_items.create!(dish_ingredient: onion2, name: "玉ねぎ", manual: false)
    @user.shopping_items.create!(dish_ingredient: milk, name: "牛乳", manual: false)

    other_plan = @other_user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :lunch)
    other_dish = other_plan.plan_dishes.create!(name: "他人の料理", position: 0)
    other_ingredient = other_dish.dish_ingredients.create!(name: "玉ねぎ")
    @other_user.shopping_items.create!(dish_ingredient: other_ingredient, name: "玉ねぎ", manual: false)

    get shopping_items_path

    assert_response :success
    assert_select ".summary-card", 0
    assert_select ".group-title span", "未購入"
    assert_select ".group-title span", { text: "献立由来", count: 0 }
    assert_select ".group-title span", { text: "手動追加", count: 0 }
    assert_select "h3", { text: "玉ねぎ", count: 2 }
    assert_select ".count-badge", 0
    assert_select "body", /昼 カレー/
    assert_select "body", /昼 サラダ/
    assert_select "h3", "牛乳"
    assert_select ".shopping-row:not(.purchased) .shopping-delete-form", 0
    assert_select ".shopping-row:not(.purchased) .shopping-edit-trigger"
    assert_select ".shopping-check-form[data-controller='shopping-toggle']"
    assert_select ".shopping-check[data-action='change->shopping-toggle#submit']"
    assert_select(
      ".shopping-list-card[data-controller='shopping-sort']" \
      "[data-shopping-sort-url-value='#{reorder_shopping_items_path(format: :json)}']",
      1
    )
    assert_select ".shopping-row--unpurchased", 3
    [onion, onion2, milk].each do |ingredient|
      assert_unpurchased_row_contract(@user.shopping_items.find_by!(dish_ingredient: ingredient))
    end
    assert_select ".edit-drawer"
    assert_select "body", { text: /他人の料理/, count: 0 }
    assert_select "body", { text: /数量/, count: 0 }
  end

  test "unpurchased group keeps its layout contract with zero and one item" do
    get shopping_items_path

    assert_response :success
    assert_select "#shopping_unpurchased_group .shopping-row--unpurchased", 0
    assert_select "#shopping_unpurchased_group .empty-state", "未購入の項目はありません。"

    item = @user.shopping_items.create!(name: "とても長い買い物項目名" * 10, manual: true)

    get shopping_items_path

    assert_response :success
    assert_select "#shopping_unpurchased_group .shopping-row--unpurchased", 1
    assert_unpurchased_row_contract(item)
  end

  test "user manually adds shopping item and blank name is rejected" do
    assert_difference -> { @user.shopping_items.manual_items.count }, 1 do
      post shopping_items_path, params: { shopping_item: { name: " 牛乳 " } }
    end

    item = @user.shopping_items.manual_items.last
    assert_redirected_to shopping_items_path
    assert_equal "牛乳", item.name
    assert_not item.purchased?
    assert_nil item.dish_ingredient_id

    get shopping_items_path
    assert_select ".group-title span", "未購入"
    assert_select "h3", "牛乳"
    assert_select "body", /手動追加/

    assert_no_difference -> { @user.shopping_items.count } do
      post shopping_items_path, params: { shopping_item: { name: " " } }
    end
    assert_response :unprocessable_content
    assert_select ".error-panel"
  end

  test "user toggles purchased state for manual item" do
    item = @user.shopping_items.create!(name: "牛乳", manual: true, purchased: false)

    patch toggle_purchased_shopping_item_path(item, format: :turbo_stream)
    assert_response :success
    assert item.reload.purchased?
    assert item.purchased_at.present?
    assert_includes response.body, "shopping_unpurchased_group"
    assert_includes response.body, "shopping_purchased_group"
    assert_not_includes response.body, "購入済みにしました"
    assert_select ".shopping-row--unpurchased", 0
    assert_select ".shopping-row.purchased", 1

    get shopping_items_path
    assert_select ".group-title span", "購入済み"
    assert_select "h3", "牛乳"

    patch toggle_purchased_shopping_item_path(item, format: :turbo_stream)
    assert_response :success
    assert_not item.reload.purchased?
    assert_nil item.purchased_at
    assert_includes response.body, "shopping_unpurchased_group"
    assert_includes response.body, "shopping_purchased_group"
    assert_not_includes response.body, "未購入に戻しました"
    assert_unpurchased_row_contract(item)
  end

  test "toggling meal plan item moves only selected row" do
    plan = @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :dinner)
    first_dish = plan.plan_dishes.create!(name: "鍋", position: 0)
    second_dish = plan.plan_dishes.create!(name: "副菜", position: 1)
    first = first_dish.dish_ingredients.create!(name: "白菜")
    second = second_dish.dish_ingredients.create!(name: "白菜")
    first_item = @user.shopping_items.create!(dish_ingredient: first, name: "白菜", manual: false)
    second_item = @user.shopping_items.create!(dish_ingredient: second, name: "白菜", manual: false)

    patch toggle_purchased_shopping_item_path(first_item)

    assert first_item.reload.purchased?
    assert_not second_item.reload.purchased?
    assert first_item.purchased_at.present?
    assert_nil second_item.purchased_at
  end

  test "user reorders unpurchased shopping items" do
    first = @user.shopping_items.create!(name: "牛乳", manual: true, sort_order: 1000)
    second = @user.shopping_items.create!(name: "卵", manual: true, sort_order: 2000)
    purchased = @user.shopping_items.create!(name: "パン", manual: true, purchased: true, sort_order: 3000)

    patch reorder_shopping_items_path(format: :json), params: { ids: [second.id, first.id, purchased.id] }, as: :json

    assert_response :success
    assert_operator second.reload.sort_order, :<, first.reload.sort_order
    assert_equal 3000, purchased.reload.sort_order
  end

  test "user updates shopping item name with turbo stream" do
    item = @user.shopping_items.create!(name: "牛乳", manual: true)

    patch shopping_item_path(item, format: :turbo_stream), params: { shopping_item: { name: " 豆乳 " } }

    assert_response :success
    assert_equal "豆乳", item.reload.name
    assert_includes response.media_type, "text/vnd.turbo-stream.html"
    assert_includes response.body, "買い物項目を更新しました"
    assert_includes response.body, "豆乳"
    assert_unpurchased_row_contract(item)
  end

  test "purchased and admin shopping rows do not use the unpurchased layout modifier" do
    unpurchased = @user.shopping_items.create!(name: "卵", manual: true)
    @user.shopping_items.create!(name: "パン", manual: true, purchased: true)

    get shopping_items_path

    assert_response :success
    assert_unpurchased_row_contract(unpurchased)
    assert_select "#shopping_purchased_group .shopping-row.purchased", 1
    assert_select "#shopping_purchased_group .shopping-row--unpurchased", 0
    purchased_children = css_select("#shopping_purchased_group .shopping-row.purchased").first.element_children
    assert_includes purchased_children[0]["class"].to_s.split, "shopping-check-form"
    assert_includes purchased_children[1]["class"].to_s.split, "shopping-row-main"
    assert_includes purchased_children[2]["class"].to_s.split, "shopping-delete-form"

    delete logout_path
    admin = User.create!(
      email: "shopping-admin@example.com",
      password: "password1",
      password_confirmation: "password1",
      role: :admin
    )
    post login_path, params: { email: admin.email, password: "password1" }
    get shopping_items_admin_user_path(@user)

    assert_response :success
    assert_select ".shopping-row", 2
    assert_select ".shopping-row--unpurchased", 0
    assert_select "[data-shopping-sort-target]", 0
    assert_select ".shopping-check", 0
    css_select(".shopping-row").each do |row|
      direct_children = row.element_children
      assert_includes direct_children[0]["class"].to_s.split, "check-icon"
      assert_includes direct_children[1]["class"].to_s.split, "shopping-row-main"
    end
  end

  test "user cannot update another user's shopping item" do
    other_item = @other_user.shopping_items.create!(name: "他人", manual: true)

    patch shopping_item_path(other_item), params: { shopping_item: { name: "変更" } }

    assert_response :not_found
    assert_equal "他人", other_item.reload.name
  end

  test "user deletes individual and purchased shopping items only in own scope" do
    item = @user.shopping_items.create!(name: "牛乳", manual: true)
    purchased = @user.shopping_items.create!(name: "パン", manual: true, purchased: true)
    unpurchased = @user.shopping_items.create!(name: "卵", manual: true)
    other_item = @other_user.shopping_items.create!(name: "他人", manual: true, purchased: true)

    assert_difference -> { @user.shopping_items.count }, -1 do
      delete shopping_item_path(item)
    end
    assert_redirected_to shopping_items_path

    delete shopping_item_path(other_item)
    assert_response :not_found
    assert @other_user.shopping_items.exists?(other_item.id)

    delete destroy_purchased_shopping_items_path
    assert_redirected_to shopping_items_path
    assert_not @user.shopping_items.exists?(purchased.id)
    assert @user.shopping_items.exists?(unpurchased.id)
    assert @other_user.shopping_items.exists?(other_item.id)
  end

  private

  def assert_unpurchased_row_contract(item)
    rows = css_select(
      "#shopping_unpurchased_group .shopping-row.shopping-row--unpurchased[data-shopping-item-id='#{item.id}']"
    )
    assert_equal 1, rows.size

    row = rows.first
    assert_equal "true", row["draggable"]
    assert_equal "item", row["data-shopping-sort-target"]

    direct_children = row.element_children
    assert_equal 3, direct_children.size
    assert_includes direct_children[0]["class"].to_s.split, "shopping-edit-trigger"
    assert_includes direct_children[1]["class"].to_s.split, "drag-handle"
    assert_includes direct_children[2]["class"].to_s.split, "shopping-check-form"

    edit_trigger = direct_children[0]
    assert_equal "button", edit_trigger.name
    assert_equal "click->shopping-edit#open", edit_trigger["data-action"]
    assert_equal item.name, edit_trigger["data-shopping-edit-name-param"]
    assert_equal ApplicationController.helpers.shopping_item_context(item),
                 edit_trigger["data-shopping-edit-context-param"]
    assert_equal shopping_item_path(item, format: :turbo_stream),
                 edit_trigger["data-shopping-edit-update-url-param"]
    assert_equal shopping_item_path(item, format: :turbo_stream),
                 edit_trigger["data-shopping-edit-delete-url-param"]

    drag_handle = direct_children[1]
    assert_equal "button", drag_handle.name
    assert_equal "並び替え", drag_handle["aria-label"]
    assert_equal "↕", drag_handle.text.strip

    check_form = direct_children[2]
    assert_equal toggle_purchased_shopping_item_path(item), check_form["action"]
    assert_equal "shopping-toggle", check_form["data-controller"]
    assert check_form.at_css("input[name='_method'][value='patch']")

    checkbox = check_form.at_css("input.shopping-check")
    assert_equal "purchased", checkbox["name"]
    assert_equal "1", checkbox["value"]
    assert_equal "change->shopping-toggle#submit", checkbox["data-action"]
    assert_equal "#{item.name}を購入済みにする", checkbox["aria-label"]
    assert_nil checkbox["checked"]
  end
end
