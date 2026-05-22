require "test_helper"

class CookingRecordMigrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "migration@example.com",
      password: "password",
      password_confirmation: "password"
    )
    @other_user = User.create!(
      email: "other-migration@example.com",
      password: "password",
      password_confirmation: "password"
    )
    post login_path, params: { email: @user.email, password: "password" }
  end

  test "past meal plans migrate to cooking records and today meal plans do not" do
    tag = @user.person_tags.create!(name: "家族")
    past = @user.meal_plans.create!(meal_date: Date.current.yesterday, meal_type: :dinner)
    past.person_tags << tag
    past.plan_dishes.create!(name: "昨日のカレー", memo: "甘口", eating_out: false, position: 0)
    past.plan_dishes.create!(name: "外食メモ", memo: "店名", eating_out: true, position: 1)

    today = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    today.plan_dishes.create!(name: "今日の料理", position: 0)

    other_past = @other_user.meal_plans.create!(meal_date: Date.current.yesterday, meal_type: :lunch)
    other_past.plan_dishes.create!(name: "他人の過去料理", position: 0)

    assert_difference -> { @user.cooking_records.count }, 2 do
      get root_path
    end

    assert_response :success
    assert past.reload.migrated?
    assert past.migrated_at.present?
    assert_not today.reload.migrated?
    assert_not other_past.reload.migrated?

    records = @user.cooking_records.order(:created_at)
    assert_equal ["昨日のカレー", "外食メモ"], records.pluck(:name)
    assert_equal [Date.current.yesterday, Date.current.yesterday], records.pluck(:cooked_on)
    assert_equal ["dinner", "dinner"], records.map(&:meal_type)
    assert_equal ["家族"], records.first.person_tags.pluck(:name)
    assert_not records.first.eating_out?
    assert records.second.eating_out?

    get meal_plans_path
    assert_response :success
    assert_select "body", { text: /昨日のカレー/, count: 0 }

    assert_no_difference -> { @user.cooking_records.count } do
      get cooking_records_path
    end
  end
end
