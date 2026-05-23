require "test_helper"

class CookingRecordMigrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "migration@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    @other_user = User.create!(
      email: "other-migration@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    post login_path, params: { email: @user.email, password: "password1" }
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

  test "index displays records grouped by date and meal type" do
    tag = @user.person_tags.create!(name: "家族")
    past = @user.meal_plans.create!(meal_date: Date.current.yesterday, meal_type: :dinner)
    past.person_tags << tag
    past.plan_dishes.create!(name: "昨日のカレー", memo: "甘口", eating_out: false, position: 0)
    past.plan_dishes.create!(name: "外食メモ", memo: "店名", eating_out: true, position: 1)

    get cooking_records_path(display_mode: "all")

    assert_response :success
    assert_select ".section-title h2", ApplicationController.helpers.app_date(Date.current.yesterday)
    assert_select ".meal-label", "昼食"
    assert_select ".meal-label", "夕食"
    assert_select ".record-dish h3", /昨日のカレー/
    assert_select ".record-dish h3", /外食メモ/
    assert_select ".meal-head .meal-tag-line", { text: /件/, count: 0 }
    assert_select ".meal-dish-detail", /甘口/
    assert_select ".record-tags span", "家族"
    assert_select ".status-badge.blue", "外食"
    assert_select ".dish-icon", "🍛"
  end

  test "index searches eating out records by eating out keyword" do
    @user.cooking_records.create!(
      name: "駅前レストラン",
      memo: "パスタ",
      cooked_on: Date.current.yesterday,
      meal_type: :dinner,
      eating_out: true
    )
    @user.cooking_records.create!(
      name: "自宅ごはん",
      cooked_on: Date.current.yesterday,
      meal_type: :dinner,
      eating_out: false
    )

    get cooking_records_path, params: { q: "外食" }

    assert_response :success
    assert_select ".record-dish h3", /駅前レストラン/
    assert_select "body", { text: /自宅ごはん/, count: 0 }
  end

  test "index searches eating out records by partial name" do
    @user.cooking_records.create!(
      name: "駅前レストラン",
      memo: "パスタ",
      cooked_on: Date.current.yesterday,
      meal_type: :dinner,
      eating_out: true
    )

    get cooking_records_path, params: { q: "レスト" }

    assert_response :success
    assert_select ".record-dish h3", /駅前レストラン/
  end

  test "index hides all records by default" do
    @user.cooking_records.create!(
      name: "昨日のカレー",
      cooked_on: Date.current.yesterday,
      meal_type: :dinner,
      eating_out: false
    )

    get cooking_records_path

    assert_response :success
    assert_select ".empty-state", /表示条件を選択/
    assert_select ".record-dish", 0
  end

  test "index searches by partial keyword and person tags with and condition" do
    family = @user.person_tags.create!(name: "家族")
    friend = @user.person_tags.create!(name: "友人")

    curry = @user.cooking_records.create!(
      name: "昨日のカレー",
      memo: "甘口",
      cooked_on: Date.current.yesterday,
      meal_type: :dinner,
      eating_out: false
    )
    curry.person_tags << [family, friend]

    fish = @user.cooking_records.create!(
      name: "焼き魚",
      memo: "塩焼き",
      cooked_on: 3.days.ago.to_date,
      meal_type: :dinner,
      eating_out: false
    )
    fish.person_tags << family

    @other_user.cooking_records.create!(
      name: "他人のカレー",
      cooked_on: Date.current.yesterday,
      meal_type: :dinner,
      eating_out: false
    )

    get cooking_records_path, params: { q: "カレ", person_tag_ids: [family.id, friend.id] }

    assert_response :success
    assert_select ".record-dish h3", /昨日のカレー/
    assert_select "body", { text: /焼き魚/, count: 0 }
    assert_select "body", { text: /他人のカレー/, count: 0 }
  end

  test "index display mode shows recent lunch or dinner records" do
    @user.cooking_records.create!(name: "昼の外食", cooked_on: Date.current.yesterday, meal_type: :lunch, eating_out: true)
    @user.cooking_records.create!(name: "夜の外食", cooked_on: Date.current.yesterday, meal_type: :dinner, eating_out: true)
    @user.cooking_records.create!(name: "古い昼食", cooked_on: 20.days.ago.to_date, meal_type: :lunch, eating_out: true)

    get cooking_records_path(display_mode: "recent_lunch")

    assert_response :success
    assert_select ".record-dish h3", /昼の外食/
    assert_select "body", { text: /夜の外食/, count: 0 }
    assert_select "body", { text: /古い昼食/, count: 0 }
  end

  test "user creates eating out cooking record with turbo stream" do
    tag = @user.person_tags.create!(name: "家族")

    assert_difference -> { @user.cooking_records.count }, 1 do
      post cooking_records_path(format: :turbo_stream), params: {
        cooking_record: {
          cooked_on: Date.current,
          meal_type: "dinner",
          name: "駅前レストラン",
          memo: "パスタ"
        },
        person_tag_ids: [tag.id]
      }
    end

    assert_response :success
    record = @user.cooking_records.order(:created_at).last
    assert record.eating_out?
    assert_equal "dinner", record.meal_type
    assert_equal ["家族"], record.person_tags.pluck(:name)
    assert_includes response.body, "駅前レストラン"
  end

  test "user updates and deletes cooking record" do
    tag = @user.person_tags.create!(name: "家族")
    record = @user.cooking_records.create!(
      name: "古い名前",
      cooked_on: Date.current.yesterday,
      meal_type: :lunch,
      eating_out: false
    )

    patch cooking_record_path(record), params: {
      name: "新しい名前",
      cooked_on: Date.current,
      meal_type: "dinner",
      memo: "修正",
      eating_out: "1",
      person_tag_ids: [tag.id]
    }

    assert_redirected_to cooking_record_path(record)
    record.reload
    assert_equal "新しい名前", record.name
    assert_equal Date.current, record.cooked_on
    assert_equal "dinner", record.meal_type
    assert record.eating_out?
    assert_equal ["家族"], record.person_tags.pluck(:name)

    assert_difference -> { @user.cooking_records.count }, -1 do
      delete cooking_record_path(record)
    end
    assert_redirected_to cooking_records_path(display_mode: "all")
  end
end
