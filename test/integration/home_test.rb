require "test_helper"

class HomeTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "home@example.com",
      password: "password",
      password_confirmation: "password"
    )
    @other_user = User.create!(
      email: "other@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  test "shows current user's today lunch and dinner only" do
    tag = @user.person_tags.create!(name: "家族")
    lunch = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    lunch.person_tags << tag
    lunch.plan_dishes.create!(name: "カレー", memo: "甘口", position: 0)
    @user.meal_plans.create!(meal_date: Date.current, meal_type: :dinner)
         .plan_dishes.create!(name: "焼き魚", position: 0)
    @other_user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
               .plan_dishes.create!(name: "他人の料理", position: 0)

    post login_path, params: { email: @user.email, password: "password" }
    follow_redirect!

    assert_response :success
    assert_select "h2", "昼食"
    assert_select "h2", "夕食"
    assert_select "h3", /カレー/
    assert_select "h3", /焼き魚/
    assert_select "span", "家族"
    assert_select "body", { text: /他人の料理/, count: 0 }
  end

  test "shows empty state when today's plans are missing" do
    post login_path, params: { email: @user.email, password: "password" }
    follow_redirect!

    assert_select ".empty-state", /まだ昼食の献立はありません/
    assert_select ".empty-state", /まだ夕食の献立はありません/
  end

  test "shows admin entry only for admin users" do
    post login_path, params: { email: @user.email, password: "password" }
    follow_redirect!
    assert_select ".admin-chip", { count: 0 }

    delete logout_path
    admin = User.create!(
      email: "admin-home@example.com",
      password: "password",
      password_confirmation: "password",
      role: :admin
    )
    post login_path, params: { email: admin.email, password: "password" }
    follow_redirect!

    assert_select ".admin-chip", "管理者ホーム"
  end
end
