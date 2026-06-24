require "test_helper"

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
end
