require "test_helper"

class HomeTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "home@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    @other_user = User.create!(
      email: "other@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
  end

  test "shows current user's today lunch and dinner only" do
    tag = @user.person_tags.create!(name: "家族")
    lunch = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    lunch.person_tags << tag
    curry = lunch.plan_dishes.create!(name: "カレー", memo: "甘口", position: 0)
    curry.dish_ingredients.create!(name: "玉ねぎ")
    curry.dish_ingredients.create!(name: "にんじん")
    @user.meal_plans.create!(meal_date: Date.current, meal_type: :dinner)
         .plan_dishes.create!(name: "焼き魚", position: 0)
    @other_user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
               .plan_dishes.create!(name: "他人の料理", position: 0)

    post login_path, params: { email: @user.email, password: "password1" }
    follow_redirect!

    assert_response :success
    assert_select ".section-title h2", ApplicationController.helpers.app_date(Date.current)
    assert_select ".meal-label", "昼食"
    assert_select ".meal-label", "夕食"
    assert_select ".meal-tag-line", "家族"
    assert_select ".dish-icon", "🍛"
    assert_select "h3", /カレー/
    assert_select "h3", /焼き魚/
    assert_select ".meal-dish-detail", /玉ねぎ, にんじん/
    assert_select ".meal-dish-detail", /甘口/
    assert_select ".page-title.with-action a.title-action", "献立を作成"
    assert_select ".quick-actions a", { text: "買い物リスト", count: 0 }
    assert_select ".quick-actions a", { text: "プロフィール", count: 0 }
    assert_select "body", { text: /他人の料理/, count: 0 }
  end

  test "shows empty state when today's plans are missing" do
    post login_path, params: { email: @user.email, password: "password1" }
    follow_redirect!

    assert_select ".meal-label", "昼食"
    assert_select ".meal-label", "夕食"
    assert_select ".empty-state", { text: "未登録", count: 2 }
  end

  test "shows admin entry only for admin users" do
    post login_path, params: { email: @user.email, password: "password1" }
    follow_redirect!
    assert_select ".admin-chip", { count: 0 }

    delete logout_path
    admin = User.create!(
      email: "admin-home@example.com",
      password: "password1",
      password_confirmation: "password1",
      role: :admin
    )
    post login_path, params: { email: admin.email, password: "password1" }
    follow_redirect!

    assert_select ".header .admin-chip", "管理者ホーム"
  end
end
