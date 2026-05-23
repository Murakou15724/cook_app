require "test_helper"

class AdminManagementTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      email: "admin-management@example.com",
      password: "password",
      password_confirmation: "password",
      role: :admin
    )
    @user = User.create!(
      email: "member-management@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  test "admin signup requires basic authentication and creates admin user" do
    get admin_signup_path
    assert_response :unauthorized

    auth = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "Keiog00d")
    assert_difference -> { User.admin.count }, 1 do
      post admin_signup_path,
           headers: { "HTTP_AUTHORIZATION" => auth },
           params: {
             user: {
               email: "created-admin@example.com",
               password: "password",
               password_confirmation: "password"
             }
           }
    end

    assert_redirected_to admin_root_path
  end

  test "admin user page links to read only user scoped lists" do
    post login_path, params: { email: @admin.email, password: "password" }

    get admin_users_path

    assert_response :success
    assert_select "a[href='#{admin_user_path(@user)}']", @user.id.to_s

    get admin_user_path(@user)

    assert_response :success
    assert_select "body", @user.email
    assert_select "body", /password_digest/
    assert_select "a[href='#{shopping_items_admin_user_path(@user)}']"
    assert_select "a[href='#{meal_plans_admin_user_path(@user)}']"
    assert_select "a[href='#{cooking_records_admin_user_path(@user)}']"
  end

  test "admin can search user scoped lists without edit links" do
    post login_path, params: { email: @admin.email, password: "password" }
    @user.cooking_records.create!(
      name: "駅前レストラン",
      cooked_on: Date.current.yesterday,
      meal_type: :dinner,
      eating_out: true
    )

    get cooking_records_admin_user_path(@user), params: { q: "レスト" }

    assert_response :success
    assert_select "h3", /駅前レストラン/
    assert_select "a", { text: /編集|削除/, count: 0 }
    assert_select "form[action*='/admin/cooking_records/']", 0
  end
end
