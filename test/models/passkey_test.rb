require "test_helper"

class PasskeyTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "passkey-model@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
  end

  test "requires credential fields and normalizes nickname" do
    passkey = @user.passkeys.build(
      external_id: "credential-id",
      public_key: "public-key",
      nickname: "  ",
      sign_count: 0
    )

    assert passkey.valid?
    assert_equal "パスキー", passkey.nickname
  end
end
