require "application_system_test_case"

class ShoppingItemsSystemTest < ApplicationSystemTestCase
  VIEWPORT_WIDTHS = [320, 375, 430].freeze

  setup do
    @user = User.create!(
      email: "shopping-system@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    meal_plan = @user.meal_plans.create!(meal_date: Date.current.tomorrow, meal_type: :dinner)
    dish = meal_plan.plan_dishes.create!(name: "とても長い献立名" * 8, position: 0)
    ingredient = dish.dish_ingredients.create!(name: "とても長い献立由来の買い物項目" * 8)
    @meal_item = @user.shopping_items.create!(
      dish_ingredient: ingredient,
      name: ingredient.name,
      manual: false,
      sort_order: 1000
    )
    @manual_item = @user.shopping_items.create!(
      name: "手動追加の買い物項目",
      manual: true,
      sort_order: 2000
    )

    visit login_path
    fill_in "メールアドレス", with: @user.email
    fill_in "パスワード", with: "password1"
    click_button "ログイン"
    assert_current_path root_path
    visit shopping_items_path
  end

  def teardown
    clear_viewport_override
    super
  end

  test "long unpurchased rows keep controls separate at supported viewport widths" do
    VIEWPORT_WIDTHS.each do |width|
      emulate_viewport(width)

      assert_equal width, page.evaluate_script("window.innerWidth")
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth")
      assert_row_layout(@meal_item)
      assert_row_layout(@manual_item)
    end
  end

  test "purchase and edit redraws preserve layout without firing other operations" do
    emulate_viewport(320)
    original_order = unpurchased_item_ids
    install_fetch_recorder

    meal_row = unpurchased_row(@meal_item)
    meal_row.find(".shopping-check").click

    assert_selector "#shopping_purchased_group .shopping-row.purchased h3", text: @meal_item.name
    assert_fetch_calls(toggle_fetch_call(@meal_item))
    assert_equal [@manual_item.id.to_s], unpurchased_item_ids
    assert_selector ".edit-drawer[hidden]", visible: :all

    reset_fetch_calls
    find(
      "#shopping_purchased_group .shopping-check[aria-label='#{@meal_item.name}を未購入に戻す']"
    ).click

    assert_selector unpurchased_row_selector(@meal_item)
    assert_fetch_calls(toggle_fetch_call(@meal_item))
    assert_equal original_order, unpurchased_item_ids
    assert_row_layout(@meal_item)

    reset_fetch_calls
    unpurchased_row(@meal_item).find(".shopping-edit-trigger").click

    assert_selector ".edit-drawer:not([hidden])"
    assert_fetch_calls
    assert_equal original_order, unpurchased_item_ids
    assert_unchecked_field_state(@meal_item)
    assert_unchecked_field_state(@manual_item)

    updated_name = "編集後も長い買い物項目名" * 8
    fill_in "shopping-edit-name", with: updated_name
    click_button "保存する"

    assert_selector "#{unpurchased_row_selector(@meal_item)} h3", text: updated_name
    assert_fetch_calls(
      path: shopping_item_path(@meal_item, format: :turbo_stream),
      method: "PATCH"
    )
    assert_selector ".edit-drawer[hidden]", visible: :all
    assert_equal original_order, unpurchased_item_ids
    assert_row_layout(@meal_item)
  end

  test "dragging by the handle only changes unpurchased order" do
    original_order = unpurchased_item_ids
    install_fetch_recorder
    install_reorder_completion_marker

    drag_handle_to(@meal_item, @manual_item)

    assert_selector "body[data-reorder-complete='true']"
    assert_fetch_calls(path: reorder_shopping_items_path(format: :json), method: "PATCH")
    assert_equal original_order.reverse, unpurchased_item_ids
    assert_selector ".edit-drawer[hidden]", visible: :all
    assert_unchecked_field_state(@meal_item)
    assert_unchecked_field_state(@manual_item)
  end

  test "failed purchase and reorder requests restore state and notify the user" do
    original_order = unpurchased_item_ids
    fail_fetches_matching("/shopping_items/reorder")

    drag_handle_to(@meal_item, @manual_item)

    assert_selector "body[data-last-alert='並び順を保存できませんでした。']"
    assert_equal original_order, unpurchased_item_ids
    assert_selector ".edit-drawer[hidden]", visible: :all

    visit shopping_items_path
    fail_fetches_matching("/toggle_purchased")
    unpurchased_row(@meal_item).find(".shopping-check").click

    assert_selector "body[data-last-alert='購入状態を更新できませんでした。']"
    assert_selector unpurchased_row_selector(@meal_item)
    assert_unchecked_field_state(@meal_item)
    assert_equal original_order, unpurchased_item_ids
  end

  private

  def emulate_viewport(width)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width,
      height: 900,
      deviceScaleFactor: 1,
      mobile: false
    )
  end

  def clear_viewport_override
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  rescue Selenium::WebDriver::Error::WebDriverError
    nil
  end

  def assert_row_layout(item)
    row = unpurchased_row(item)
    metrics = page.evaluate_script(<<~JAVASCRIPT, row.native)
      (() => {
        const row = arguments[0]
        const main = row.querySelector(".shopping-row-main").getBoundingClientRect()
        const handle = row.querySelector(".drag-handle").getBoundingClientRect()
        const check = row.querySelector(".shopping-check").getBoundingClientRect()
        const rowRect = row.getBoundingClientRect()

        return {
          row: { left: rowRect.left, right: rowRect.right, top: rowRect.top, bottom: rowRect.bottom },
          main: { left: main.left, right: main.right, top: main.top, bottom: main.bottom },
          handle: {
            left: handle.left, right: handle.right, top: handle.top, bottom: handle.bottom, width: handle.width
          },
          check: {
            left: check.left, right: check.right, top: check.top, bottom: check.bottom, width: check.width
          }
        }
      })()
    JAVASCRIPT

    assert_operator metrics.dig("main", "right"), :<=, metrics.dig("handle", "left")
    assert_operator metrics.dig("handle", "right"), :<=, metrics.dig("check", "left")
    assert_operator metrics.dig("row", "left"), :<=, metrics.dig("main", "left")
    assert_operator metrics.dig("check", "right"), :<=, metrics.dig("row", "right")
    ["main", "handle", "check"].each do |part|
      assert_operator metrics.dig("row", "top"), :<=, metrics.dig(part, "top")
      assert_operator metrics.dig(part, "bottom"), :<=, metrics.dig("row", "bottom")
    end
    assert_in_delta 34, metrics.dig("handle", "width"), 0.5
    assert_in_delta 20, metrics.dig("check", "width"), 0.5
  end

  def unpurchased_row(item)
    find(unpurchased_row_selector(item))
  end

  def unpurchased_row_selector(item)
    ".shopping-row--unpurchased[data-shopping-item-id='#{item.id}']"
  end

  def unpurchased_item_ids
    all(".shopping-row--unpurchased", minimum: 1).map { |row| row["data-shopping-item-id"] }
  end

  def assert_unchecked_field_state(item)
    checkbox = unpurchased_row(item).find(".shopping-check")
    assert_not checkbox.checked?
    assert_not checkbox.disabled?
  end

  def drag_handle_to(source_item, target_item)
    source = unpurchased_row(source_item).find(".drag-handle")
    target = unpurchased_row(target_item)

    page.driver.browser.action
        .move_to(source.native)
        .pointer_down(:left)
        .pause(duration: 0.2)
        .move_to(target.native, 0, 10, duration: 0.4)
        .pause(duration: 0.2)
        .pointer_up(:left)
        .perform
  end

  def install_fetch_recorder
    page.execute_script(<<~JAVASCRIPT)
      const originalFetch = window.fetch.bind(window)
      window.__shoppingFetchCalls = []
      window.fetch = (...args) => {
        const url = new URL(String(args[0]), window.location.href)
        const options = args[1] || {}
        window.__shoppingFetchCalls.push({
          path: `${url.pathname}${url.search}`,
          method: String(options.method || "GET").toUpperCase()
        })
        return originalFetch(...args)
      }
    JAVASCRIPT
  end

  def reset_fetch_calls
    page.execute_script("window.__shoppingFetchCalls = []")
  end

  def toggle_fetch_call(item)
    { path: toggle_purchased_shopping_item_path(item), method: "POST" }
  end

  def assert_fetch_calls(*expected_calls)
    assert_equal(
      expected_calls.map(&:stringify_keys),
      page.evaluate_script("window.__shoppingFetchCalls || []")
    )
  end

  def install_reorder_completion_marker
    page.execute_script(<<~JAVASCRIPT)
      const originalFetch = window.fetch.bind(window)
      window.fetch = (...args) => {
        const result = originalFetch(...args)
        if (String(args[0]).includes("/shopping_items/reorder")) {
          result.finally(() => { document.body.dataset.reorderComplete = "true" })
        }
        return result
      }
    JAVASCRIPT
  end

  def fail_fetches_matching(path_fragment)
    page.execute_script(<<~JAVASCRIPT, path_fragment)
      const pathFragment = arguments[0]
      const originalFetch = window.fetch.bind(window)
      window.fetch = (...args) => {
        if (String(args[0]).includes(pathFragment)) {
          return Promise.reject(new Error("System test forced network failure"))
        }
        return originalFetch(...args)
      }
      window.alert = (message) => { document.body.dataset.lastAlert = message }
    JAVASCRIPT
  end
end
