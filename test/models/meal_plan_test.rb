require "test_helper"

class MealPlanTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "meal@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  test "prevents duplicate meal frame per user date and meal type" do
    @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    duplicate = @user.meal_plans.new(meal_date: Date.current, meal_type: :lunch)

    assert_not duplicate.valid?
  end

  test "allows lunch and dinner on same date" do
    @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    dinner = @user.meal_plans.new(meal_date: Date.current, meal_type: :dinner)

    assert dinner.valid?
  end
end
