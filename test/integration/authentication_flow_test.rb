require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "user signs up and is logged in" do
    post signup_path, params: {
      user: {
        email: "new@example.com",
        password: "password",
        password_confirmation: "password"
      }
    }

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_select "h1", "今日の献立"
  end

  test "signup rejects invalid input" do
    post signup_path, params: {
      user: {
        email: "invalid",
        password: "short",
        password_confirmation: "short"
      }
    }

    assert_response :unprocessable_content
    assert_select ".error-panel"
  end

  test "login succeeds and logout protects root" do
    User.create!(
      email: "login@example.com",
      password: "password",
      password_confirmation: "password"
    )

    post login_path, params: { email: "login@example.com", password: "password" }
    assert_redirected_to root_path

    delete logout_path
    assert_redirected_to login_path

    get root_path
    assert_redirected_to login_path
  end

  test "login rejects bad credentials and has no reset link" do
    get login_path
    assert_response :success
    assert_select "a", { text: /パスワード/, count: 0 }

    post login_path, params: { email: "none@example.com", password: "password" }
    assert_response :unprocessable_content
    assert_select ".flash-alert"
  end
end
