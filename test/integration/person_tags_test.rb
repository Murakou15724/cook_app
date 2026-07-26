require "test_helper"
require "minitest/mock"

class PersonTagsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "person-tags@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    @other_user = User.create!(
      email: "other-person-tags@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    post login_path, params: { email: @user.email, password: "password1" }
  end

  test "user creates edits and deletes a person tag" do
    assert_difference -> { @user.person_tags.count }, 1 do
      post person_tags_path, params: {
        person_tag: { name: " 家族 ", default_selected: "1" }
      }
    end

    tag = @user.person_tags.order(:created_at).last
    assert_redirected_to person_tags_path
    assert_equal "家族", tag.name
    assert tag.default_selected?

    patch person_tag_path(tag), params: {
      person_tag: { name: "友人", default_selected: "0" }
    }
    assert_redirected_to person_tags_path

    tag.reload
    assert_equal "友人", tag.name
    assert_not tag.default_selected?

    assert_difference -> { @user.person_tags.count }, -1 do
      delete person_tag_path(tag)
    end
    assert_redirected_to person_tags_path
  end

  test "user cannot save blank or duplicate person tag" do
    @user.person_tags.create!(name: "家族")

    assert_no_difference -> { @user.person_tags.count } do
      post person_tags_path, params: { person_tag: { name: "" } }
    end
    assert_response :unprocessable_content
    assert_select ".error-panel"

    assert_no_difference -> { @user.person_tags.count } do
      post person_tags_path, params: { person_tag: { name: "家族" } }
    end
    assert_response :unprocessable_content
    assert_select ".error-panel"
  end

  test "person tags are scoped to current user" do
    visible = @user.person_tags.create!(name: "自分")
    hidden = @other_user.person_tags.create!(name: "他人")

    get person_tags_path
    assert_response :success
    assert_select "body", /自分/
    assert_select "body", { text: /他人/, count: 0 }

    get edit_person_tag_path(hidden)
    assert_response :not_found

    assert_no_difference -> { @other_user.person_tags.count } do
      delete person_tag_path(hidden)
    end
    assert_response :not_found

    assert_difference -> { @user.person_tags.count }, -1 do
      delete person_tag_path(visible)
    end
  end

  test "default selected person tags are checked on new meal plan page" do
    default_tag = @user.person_tags.create!(name: "家族", default_selected: true)
    normal_tag = @user.person_tags.create!(name: "友人", default_selected: false)

    get new_meal_plan_path
    assert_response :success
    assert_select "input[name='person_tag_ids[]'][value='#{default_tag.id}'][checked='checked']"
    assert_select "input[name='person_tag_ids[]'][value='#{normal_tag.id}'][checked='checked']", count: 0
  end

  test "cooking tag routes and links do not exist" do
    assert_nil Rails.application.routes.named_routes[:cooking_tags]

    get person_tags_path
    assert_response :success
    assert_select "body", { text: /料理タグ/, count: 0 }

    get new_meal_plan_path
    assert_response :success
    assert_select "body", { text: /料理タグ/, count: 0 }
  end

  test "management displays saved order and enables sorting only for multiple tags" do
    first = @user.person_tags.create!(name: "家族")
    second = @user.person_tags.create!(name: "友人")
    first.update!(sort_order: 2000)
    second.update!(sort_order: 1000)

    get person_tags_path

    assert_response :success
    assert_equal [second.id.to_s, first.id.to_s],
                 css_select(".person-tag-row").map { |row| row["data-person-tag-id"] }
    assert_select "[data-controller='person-tag-sort']"
    assert_select "[data-person-tag-sort-url-value='#{reorder_person_tags_path(format: :json)}']"
    assert_select ".person-tag-sort-handle[disabled]", count: 0

    delete person_tag_path(first)
    get person_tags_path
    assert_select ".person-tag-sort-handle[disabled]", count: 1
  end

  test "reorder saves a complete permutation atomically without changing tag data" do
    first = @user.person_tags.create!(name: "家族", default_selected: true)
    second = @user.person_tags.create!(name: "友人", default_selected: false)
    meal_plan = @user.meal_plans.create!(meal_date: Date.current, meal_type: :lunch)
    meal_plan.person_tags << first
    record = @user.cooking_records.create!(name: "カレー", cooked_on: Date.current, meal_type: :lunch)
    record.person_tags << second
    previous_updated_at = 1.day.ago
    first.update_column(:updated_at, previous_updated_at)
    second.update_column(:updated_at, previous_updated_at)

    patch reorder_person_tags_path(format: :json),
          params: { ids: [second.id, first.id] },
          as: :json

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal({ "ok" => true }, JSON.parse(response.body))
    assert_equal [second, first], @user.person_tags.display_ordered.to_a
    assert_equal ["家族", "友人"], [first.reload.name, second.reload.name]
    assert first.default_selected?
    assert_not second.default_selected?
    assert_equal [first.id], meal_plan.reload.person_tag_ids
    assert_equal [second.id], record.reload.person_tag_ids
    assert_operator first.updated_at, :>, previous_updated_at
    assert_operator second.updated_at, :>, previous_updated_at
  end

  test "reorder accepts canonical positive digit strings" do
    first = @user.person_tags.create!(name: "家族")
    second = @user.person_tags.create!(name: "友人")

    patch reorder_person_tags_path(format: :json),
          params: { ids: [second.id.to_s, first.id.to_s] },
          as: :json

    assert_response :success
    assert_equal [second, first], @user.person_tags.display_ordered.to_a
  end

  test "reorder requires a JSON request body" do
    first = @user.person_tags.create!(name: "家族")
    second = @user.person_tags.create!(name: "友人")
    original = @user.person_tags.display_ordered.to_a

    patch reorder_person_tags_path(format: :json), params: { ids: [second.id, first.id] }

    assert_response :unprocessable_content
    assert_equal original, @user.person_tags.reload.display_ordered.to_a
  end

  test "reorder rejects malformed and incomplete id arrays without partial updates" do
    first = @user.person_tags.create!(name: "家族")
    second = @user.person_tags.create!(name: "友人")
    other = @other_user.person_tags.create!(name: "他人")
    original = @user.person_tags.order(:id).pluck(:id, :sort_order, :updated_at)
    invalid_payloads = [
      {},
      { ids: nil },
      { ids: "" },
      { ids: [first.id] },
      { ids: [first.id, first.id] },
      { ids: [first.id, second.id, other.id] },
      { ids: [first.id, other.id] },
      { ids: [first.id, PersonTag.maximum(:id) + 10_000] },
      { ids: [first.id, 0] },
      { ids: [first.id, -1] },
      { ids: [first.id, 1.5] },
      { ids: [first.id, true] },
      { ids: [first.id, []] },
      { ids: [first.id, ""] },
      { ids: [first.id, "+#{second.id}"] },
      { ids: [first.id, "#{second.id}.0"] },
      { ids: [first.id, "#{second.id}e0"] },
      { ids: [first.id, "0#{second.id}"] }
    ]

    invalid_payloads.each do |payload|
      patch reorder_person_tags_path(format: :json), params: payload, as: :json

      assert_response :unprocessable_content, "expected rejection for #{payload.inspect}"
      assert_equal({ "ok" => false }, JSON.parse(response.body))
      assert_equal original, @user.person_tags.order(:id).pluck(:id, :sort_order, :updated_at)
    end
  end

  test "reorder rolls back all updates when a tag update fails" do
    first = @user.person_tags.create!(name: "家族")
    second = @user.person_tags.create!(name: "友人")
    original = @user.person_tags.order(:id).pluck(:id, :sort_order, :updated_at)
    update_count = 0
    failing_update = lambda do |tag, sort_order:, updated_at:|
      update_count += 1
      raise ActiveRecord::RecordInvalid.new(tag) if update_count == 2

      tag.update!(sort_order: sort_order, updated_at: updated_at)
    end

    PersonTag.stub(:update_reordered_tag!, failing_update) do
      patch reorder_person_tags_path(format: :json),
            params: { ids: [second.id, first.id] },
            as: :json
    end

    assert_response :unprocessable_content
    assert_equal original, @user.person_tags.order(:id).pluck(:id, :sort_order, :updated_at)
  end

  test "unauthenticated JSON reorder receives 401 without a redirect" do
    delete logout_path

    patch reorder_person_tags_path(format: :json), params: { ids: [] }, as: :json

    assert_response :unauthorized
    assert_not response.redirect?
    assert_equal({ "ok" => false }, JSON.parse(response.body))
  end
end
