require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes email and defaults to member role" do
    user = User.create!(
      email: "  TEST@Example.COM ",
      password: "password",
      password_confirmation: "password"
    )

    assert_equal "test@example.com", user.email
    assert user.member?
  end

  test "requires valid unique email and six character password" do
    User.create!(
      email: "taken@example.com",
      password: "password",
      password_confirmation: "password"
    )

    duplicate = User.new(
      email: "TAKEN@example.com",
      password: "password",
      password_confirmation: "password"
    )
    invalid_email = User.new(
      email: "invalid",
      password: "password",
      password_confirmation: "password"
    )
    short_password = User.new(
      email: "short@example.com",
      password: "short",
      password_confirmation: "short"
    )

    assert_not duplicate.valid?
    assert_not invalid_email.valid?
    assert_not short_password.valid?
  end

  test "does not destroy the last admin" do
    admin = User.create!(
      email: "admin@example.com",
      password: "password",
      password_confirmation: "password",
      role: :admin
    )

    assert_not admin.destroy
    assert_includes admin.errors[:base], "最後の管理者は削除できません"
  end
end
