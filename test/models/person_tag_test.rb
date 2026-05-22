require "test_helper"

class PersonTagTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "tag-owner@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  test "normalizes name and requires presence" do
    tag = @user.person_tags.create!(name: "  家族  ")
    blank = @user.person_tags.new(name: "   ")

    assert_equal "家族", tag.name
    assert_not blank.valid?
  end

  test "prevents duplicate names per user but allows same name for different users" do
    @user.person_tags.create!(name: "家族")
    duplicate = @user.person_tags.new(name: "家族")
    other_user = User.create!(
      email: "other-tag-owner@example.com",
      password: "password",
      password_confirmation: "password"
    )
    other_tag = other_user.person_tags.new(name: "家族")

    assert_not duplicate.valid?
    assert other_tag.valid?
  end
end
