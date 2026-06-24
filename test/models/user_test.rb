require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes email and defaults to member role" do
    user = User.create!(
      email: "  TEST@Example.COM ",
      password: "password1",
      password_confirmation: "password1"
    )

    assert_equal "test@example.com", user.email
    assert user.member?
  end

  test "normalizes nickname and assigns default nickname when blank" do
    named = User.create!(
      email: "named@example.com",
      nickname: "  料理担当  ",
      password: "password1",
      password_confirmation: "password1"
    )
    unnamed = User.create!(
      email: "unnamed@example.com",
      password: "password1",
      password_confirmation: "password1"
    )

    assert_equal "料理担当", named.nickname
    assert_equal "料理担当", named.display_nickname
    assert_equal "ユーザー#{unnamed.id}", unnamed.reload.nickname
    assert_equal "ユーザー#{unnamed.id}", unnamed.display_nickname
  end

  test "requires valid unique email and password policy" do
    User.create!(
      email: "taken@example.com",
      password: "password1",
      password_confirmation: "password1"
    )

    duplicate = User.new(
      email: "TAKEN@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    invalid_email = User.new(
      email: "invalid",
      password: "password1",
      password_confirmation: "password1"
    )
    short_password = User.new(
      email: "short@example.com",
      password: "abc12",
      password_confirmation: "abc12"
    )
    long_password = User.new(
      email: "long@example.com",
      password: "abc123456789012345678",
      password_confirmation: "abc123456789012345678"
    )
    letters_only = User.new(
      email: "letters@example.com",
      password: "password",
      password_confirmation: "password"
    )
    numbers_only = User.new(
      email: "numbers@example.com",
      password: "123456",
      password_confirmation: "123456"
    )
    symbol_password = User.new(
      email: "symbol@example.com",
      password: "abc123!",
      password_confirmation: "abc123!"
    )

    assert_not duplicate.valid?
    assert_not invalid_email.valid?
    assert_not short_password.valid?
    assert_not long_password.valid?
    assert_not letters_only.valid?
    assert_not numbers_only.valid?
    assert_not symbol_password.valid?
  end

  test "nickname is at most twenty characters" do
    user = User.new(
      email: "nickname@example.com",
      nickname: "あ" * 21,
      password: "password1",
      password_confirmation: "password1"
    )

    assert_not user.valid?
  end

  test "does not destroy the last admin" do
    admin = User.create!(
      email: "admin@example.com",
      password: "password1",
      password_confirmation: "password1",
      role: :admin
    )

    assert_not admin.destroy
    assert_includes admin.errors[:base], "最後の管理者は削除できません"
  end
end
