require "test_helper"

class ProfilesTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "profile@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    post login_path, params: { email: @user.email, password: "password1" }
  end

  test "user edits nickname from profile" do
    get edit_profile_path

    assert_response :success
    assert_select "input[name='user[nickname]'][autocomplete='off']"

    patch profile_path, params: {
      user: {
        email: @user.email,
        nickname: "週末シェフ",
        password: "",
        password_confirmation: ""
      }
    }

    assert_redirected_to root_path
    assert_equal "週末シェフ", @user.reload.nickname
  end

  test "blank nickname on profile falls back to default nickname" do
    @user.update!(nickname: "一時名")

    patch profile_path, params: {
      user: {
        email: @user.email,
        nickname: "",
        password: "",
        password_confirmation: ""
      }
    }

    assert_redirected_to root_path
    assert_equal "ユーザー#{@user.id}", @user.reload.nickname
  end
end
