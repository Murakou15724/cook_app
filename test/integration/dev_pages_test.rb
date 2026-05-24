require "test_helper"

class DevPagesTest < ActionDispatch::IntegrationTest
  test "shows development page sections in requested order" do
    admin = User.create!(
      email: "dev-pages-admin@example.com",
      password: "password1",
      password_confirmation: "password1",
      role: :admin
    )

    post login_path, params: { email: admin.email, password: "password1" }
    get dev_pages_path

    assert_response :success
    headings = css_select(".dev-grid .section-title h2").map(&:text)
    assert_equal ["管理者・エラー", "一般画面", "IDが必要な画面"], headings
  end
end
