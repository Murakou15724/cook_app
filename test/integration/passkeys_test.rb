require "test_helper"

class PasskeysTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "passkey@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
  end

  test "registration options require login and return webauthn creation options" do
    post passkey_registration_options_path, as: :json
    assert_redirected_to login_path

    post login_path, params: { email: @user.email, password: "password1" }
    post passkey_registration_options_path, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body["challenge"].present?
    assert_equal @user.reload.webauthn_id, body.dig("user", "id")
    assert_equal @user.email, body.dig("user", "name")
  end

  test "login options preserve password login and expose passkey request options" do
    @user.passkeys.create!(
      external_id: "credential-id",
      public_key: "public-key",
      nickname: "端末",
      sign_count: 0
    )

    post passkey_login_options_path, params: { email: @user.email }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body["challenge"].present?
    assert_equal ["credential-id"], body["allowCredentials"].map { |credential| credential["id"] }

    post login_path, params: { email: @user.email, password: "password1" }
    assert_redirected_to root_path
  end
end
