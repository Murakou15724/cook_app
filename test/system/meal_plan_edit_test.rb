require "application_system_test_case"

class MealPlanEditTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(
      email: "meal-plan-system@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    @meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    @first_dish = @meal_plan.plan_dishes.create!(name: "カレー", position: 0)
    @second_dish = @meal_plan.plan_dishes.create!(name: "サラダ", position: 1)

    visit login_path
    fill_in "メールアドレス", with: @user.email
    fill_in "パスワード", with: "password1"
    click_button "ログイン"
    assert_current_path root_path
  end

  test "dish selection opens the full edit page directly" do
    visit meal_plans_path

    find("a.meal-edit-trigger", text: "カレー").click

    assert_current_path edit_meal_plan_path(@meal_plan)
    assert_selector "h1", text: "献立編集"
  end

  test "dish link is reachable with tab and opens with enter" do
    visit meal_plans_path
    dish_link = find("a.meal-edit-trigger", text: "カレー")

    10.times do
      page.driver.browser.action.send_keys(:tab).perform
      break if page.evaluate_script("document.activeElement.textContent.includes('カレー')")
    end

    assert_equal dish_link[:href], page.evaluate_script("document.activeElement.href")
    page.driver.browser.action.send_keys(:enter).perform

    assert_current_path edit_meal_plan_path(@meal_plan)
    assert_selector "h1", text: "献立編集"
  end

  test "dish link uses native navigation when JavaScript is disabled" do
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: true)
    visit meal_plans_path

    find("a.meal-edit-trigger", text: "カレー").click

    assert_current_path edit_meal_plan_path(@meal_plan)
    assert_selector "h1", text: "献立編集"
  ensure
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
  end

  test "meal plan list remains operable without horizontal overflow at 320 pixels" do
    page.current_window.resize_to(320, 800)
    visit meal_plans_path

    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, page.evaluate_script("window.innerWidth")
    assert_selector ".meal-label", text: "昼食"
    assert_selector "a.meal-edit-trigger", text: "カレー"
    assert_selector ".empty-state", text: "未登録", count: 1
    assert_no_selector "a", text: "未登録"

    find("a.meal-edit-trigger", text: "カレー").click
    assert_current_path edit_meal_plan_path(@meal_plan)
  end

  test "dish deletion confirmation cancel preserves ids and ok moves focus to the adjacent dish" do
    visit edit_meal_plan_path(@meal_plan)
    first_card = find("section.dish-card[data-dish-index='0']")

    dismiss_confirm("この料理を削除しますか？") do
      first_card.click_button "削除"
    end
    assert_selector "input[name='dishes[0][id]'][value='#{@first_dish.id}']", count: 1, visible: :all
    assert_selector "input[name='dishes[1][id]'][value='#{@second_dish.id}']", count: 1, visible: :all

    accept_confirm("この料理を削除しますか？") do
      first_card.click_button "削除"
    end
    assert_no_selector "input[value='#{@first_dish.id}'][name$='[id]']", visible: :all
    assert_equal "dishes_1_name", page.evaluate_script("document.activeElement.id")
  end

  test "dish deletion is keyboard operable and the final deletion focuses add button" do
    visit edit_meal_plan_path(@meal_plan)
    second_card = find("section.dish-card[data-dish-index='1']")
    second_delete = second_card.find("button", text: "削除")

    accept_confirm("この料理を削除しますか？") do
      second_delete.send_keys(:enter)
    end
    assert_equal "dishes_0_name", page.evaluate_script("document.activeElement.id")

    first_delete = find("section.dish-card[data-dish-index='0'] button", text: "削除")
    accept_confirm("この料理を削除しますか？") do
      first_delete.send_keys(:space)
    end
    assert_no_selector "section.dish-card"
    assert_equal "料理を追加", page.evaluate_script("document.activeElement.textContent.trim()")
  end

  test "full edit remains operable without horizontal overflow at 320 pixels" do
    page.current_window.resize_to(320, 800)
    visit edit_meal_plan_path(@meal_plan)

    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, page.evaluate_script("window.innerWidth")
    assert_selector "input[name='meal_date']"
    assert_button "料理を追加"
    assert_button "更新する"

    first_card = find("section.dish-card[data-dish-index='0']")
    assert first_card.find_button("削除").visible?
    dismiss_confirm("この料理を削除しますか？") do
      first_card.click_button "削除"
    end
    assert_selector "section.dish-card", count: 2
    assert_selector "input[name='dishes[0][id]'][value='#{@first_dish.id}']", count: 1, visible: :all
  end
end
