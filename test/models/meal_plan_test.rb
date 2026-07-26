require "test_helper"

class MealPlanTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "meal@example.com",
      password: "password1",
      password_confirmation: "password1"
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

  test "orders attached person tags without querying when the association is loaded" do
    first = @user.person_tags.create!(name: "家族")
    second = @user.person_tags.create!(name: "友人")
    first.update!(sort_order: 2000)
    second.update!(sort_order: 1000)
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    meal_plan.person_tags << [first, second]

    unloaded = MealPlan.find(meal_plan.id)
    assert_equal [second, first], unloaded.display_ordered_person_tags

    loaded = MealPlan.includes(:person_tags).find(meal_plan.id)
    assert_no_queries do
      assert_equal [second, first], loaded.display_ordered_person_tags
    end
  end

  private

  def assert_no_queries
    queries = []
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:cached]
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    assert_empty queries
  end
end
