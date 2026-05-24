require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "user signs up and is logged in" do
    post signup_path, params: {
      user: {
        email: "new@example.com",
        nickname: "新規ユーザー",
        password: "password1",
        password_confirmation: "password1"
      }
    }

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_select "h1", "今日の献立"
    assert_equal "新規ユーザー", User.find_by!(email: "new@example.com").nickname
  end

  test "signup assigns default nickname when nickname is blank" do
    post signup_path, params: {
      user: {
        email: "blank-nickname@example.com",
        nickname: "",
        password: "password1",
        password_confirmation: "password1"
      }
    }

    user = User.find_by!(email: "blank-nickname@example.com")
    assert_redirected_to root_path
    assert_equal "ユーザー#{user.id}", user.nickname
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
      password: "password1",
      password_confirmation: "password1"
    )

    post login_path, params: { email: "login@example.com", password: "password1" }
    assert_redirected_to root_path

    delete logout_path
    assert_redirected_to login_path

    get root_path
    assert_redirected_to login_path
  end

  test "login rejects bad credentials and has no reset link" do
    get login_path
    assert_response :success
    assert_select "form[autocomplete='off']"
    assert_select "input[name='email'][autocomplete='off']"
    assert_select "input[name='password'][autocomplete='off'][type='password']"
    assert_select "button[data-action='password-visibility#toggle']", "表示"
    assert_select "button[data-action='passkey#login']", "パスキーでログイン"
    assert_select "a", { text: /パスワード/, count: 0 }

    post login_path, params: { email: "none@example.com", password: "password1" }
    assert_response :unprocessable_content
    assert_select ".flash-alert"
  end

  test "signup form disables autocomplete" do
    get signup_path
    assert_response :success
    assert_select "form[autocomplete='off']"
    assert_select "input[name='user[email]'][autocomplete='off']"
    assert_select "input[name='user[nickname]'][autocomplete='off']"
    assert_select "input[name='user[password]'][autocomplete='off']"
    assert_select "input[name='user[password_confirmation]'][autocomplete='off']"
  end
end
