require "test_helper"

class CookingRecordTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "cooking-record-model@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
  end

  test "orders attached person tags from loaded and unloaded associations" do
    first = @user.person_tags.create!(name: "家族")
    second = @user.person_tags.create!(name: "友人")
    first.update!(sort_order: 2000)
    second.update!(sort_order: 1000)
    record = @user.cooking_records.create!(
      name: "カレー",
      cooked_on: Date.current,
      meal_type: :lunch
    )
    record.person_tags << [first, second]

    assert_equal [second, first], CookingRecord.find(record.id).display_ordered_person_tags

    loaded = CookingRecord.includes(:person_tags).find(record.id)
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
