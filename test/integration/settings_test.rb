require "test_helper"

class SettingsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "settings@example.com",
      password: "password",
      password_confirmation: "password"
    )
    post login_path, params: { email: @user.email, password: "password" }
  end

  test "show links to profile edit and person tags" do
    get settings_path

    assert_response :success
    assert_select "h1", "設定ページ"
    assert_select ".dev-link-row span", "プロフィール編集"
    assert_select ".dev-link-row span", "人物タグ設定"
    assert_select "a[href='#{edit_profile_path}']", "開く", count: 1
    assert_select "a[href='#{person_tags_path}']", "開く", count: 1
  end

  test "bottom nav uses settings instead of tag" do
    get root_path

    assert_response :success
    assert_select ".bottom-nav a", "設定"
    assert_select ".bottom-nav a", { text: "タグ", count: 0 }
    assert_select ".bottom-nav a[href='#{settings_path}']"
  end
end
