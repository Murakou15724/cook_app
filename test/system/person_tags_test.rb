require "application_system_test_case"

class PersonTagsSystemTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(
      email: "person-tags-system@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    @first = @user.person_tags.create!(name: "家族")
    @second = @user.person_tags.create!(name: "友人")
    @third = @user.person_tags.create!(name: "知人")

    page.current_window.resize_to(1400, 1400)
    visit login_path
    fill_in "メールアドレス", with: @user.email
    fill_in "パスワード", with: "password1"
    click_button "ログイン"
    assert_current_path root_path

    visit person_tags_path
    assert_current_path person_tags_path
    assert_selector ".person-tag-row .person-tag-sort-handle", count: 3
  end

  test "mouse dragging the first tag to the end saves and persists the exact order" do
    install_fetch_recorder
    install_reorder_completion_marker

    drag_handle_to(@first, @third)

    assert_selector "body[data-person-tag-reorder-complete='true']"
    assert_equal 1, reorder_fetch_calls.size
    expected_order = [@second.id.to_s, @third.id.to_s, @first.id.to_s]
    assert_equal expected_order, person_tag_ids
    assert_current_path person_tags_path

    visit person_tags_path
    assert_equal expected_order, person_tag_ids
  end

  test "keyboard pickup movement drop cancel and edge no-ops are accessible" do
    install_fetch_recorder

    tag_handle(@second).send_keys(:enter)
    tag_handle(@second).send_keys(:home)
    tag_handle(@second).send_keys(:arrow_up)
    tag_handle(@second).send_keys(:end)
    tag_handle(@second).send_keys(:arrow_down)
    tag_handle(@second).send_keys(:escape)

    assert_equal [@first.id.to_s, @second.id.to_s, @third.id.to_s], person_tag_ids
    assert_equal 0, reorder_fetch_calls.size
    assert_text "移動をキャンセルしました"
    assert_equal tag_handle(@second).native, page.driver.browser.switch_to.active_element

    install_reorder_completion_marker
    tag_handle(@first).send_keys(:space)
    tag_handle(@first).send_keys(:arrow_down)
    tag_handle(@first).send_keys(:enter)

    assert_selector "body[data-person-tag-reorder-complete='true']"
    assert_equal [@second.id.to_s, @first.id.to_s, @third.id.to_s], person_tag_ids
    assert_text "並び順を保存しました"
    assert_equal tag_handle(@first).native, page.driver.browser.switch_to.active_element
  end

  test "pointer dragging is ignored while a keyboard move is active" do
    original_order = person_tag_ids
    install_fetch_recorder

    tag_handle(@first).send_keys(:enter)
    drag_handle_to(@second, @third)

    assert_equal original_order, person_tag_ids
    assert_equal 0, reorder_fetch_calls.size

    tag_handle(@first).send_keys(:escape)

    assert_equal original_order, person_tag_ids
    assert_equal 0, reorder_fetch_calls.size
    assert_text "移動をキャンセルしました"

    visit person_tags_path
    assert_equal original_order, person_tag_ids
  end

  test "saving disables only reorder controls and announces progress" do
    hold_reorder_fetch

    tag_handle(@first).send_keys(:enter)
    tag_handle(@first).send_keys(:arrow_down)
    tag_handle(@first).send_keys(:space)

    assert_selector ".person-tag-sort-list[aria-busy='true']"
    assert_selector ".person-tag-sort-handle[disabled]", count: 3
    assert_text "並び順を保存しています"
    assert_selector "a[href='#{edit_person_tag_path(@first)}']"
    assert_selector "form[action='#{person_tag_path(@first)}'] button:not([disabled])"

    resolve_held_reorder_fetch

    assert_selector ".person-tag-sort-list[aria-busy='false']"
    assert_selector ".person-tag-sort-handle:not([disabled])", count: 3
    assert_text "並び順を保存しました"
    assert_equal tag_handle(@first).native, page.driver.browser.switch_to.active_element
  end

  test "failed save restores confirmed order keeps focus and can be retried" do
    original_order = person_tag_ids
    reject_first_reorder_fetch

    keyboard_move_down(@first)

    assert_selector "body[data-last-alert='並び順を保存できませんでした。']"
    assert_equal original_order, person_tag_ids
    assert_text "保存済みの順序へ戻しました"
    assert_equal tag_handle(@first).native, page.driver.browser.switch_to.active_element

    keyboard_move_down(@first)

    assert_text "並び順を保存しました"
    assert_equal [@second.id.to_s, @first.id.to_s, @third.id.to_s], person_tag_ids
    assert_equal 2, page.evaluate_script("window.__personTagReorderAttempts")
    assert_equal tag_handle(@first).native, page.driver.browser.switch_to.active_element
  end

  test "no-op and zero or one tag do not send reorder requests" do
    install_fetch_recorder

    tag_handle(@first).send_keys(:space)
    tag_handle(@first).send_keys(:enter)

    assert_text "並び順は変更されていません"
    assert_equal 0, reorder_fetch_calls.size

    @second.destroy!
    @third.destroy!
    visit person_tags_path
    assert_selector ".person-tag-sort-handle[disabled]", count: 1
    assert_equal 0, reorder_fetch_calls.size

    @first.destroy!
    visit person_tags_path
    assert_selector ".person-tag-sort-handle", count: 0
    assert_text "人物タグはまだありません"
  end

  private

  def person_tag_ids
    all(".person-tag-row", minimum: 1).map { |row| row["data-person-tag-id"] }
  end

  def tag_handle(tag)
    find(".person-tag-row[data-person-tag-id='#{tag.id}'] .person-tag-sort-handle")
  end

  def keyboard_move_down(tag)
    tag_handle(tag).send_keys(:space)
    tag_handle(tag).send_keys(:arrow_down)
    tag_handle(tag).send_keys(:enter)
  end

  def drag_handle_to(source_tag, target_tag)
    source = tag_handle(source_tag)
    target = find(".person-tag-row[data-person-tag-id='#{target_tag.id}']")

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
      window.__personTagFetchCalls = []
      window.fetch = (...args) => {
        const url = new URL(String(args[0]), window.location.href)
        const options = args[1] || {}
        window.__personTagFetchCalls.push({
          path: `${url.pathname}${url.search}`,
          method: String(options.method || "GET").toUpperCase()
        })
        return originalFetch(...args)
      }
    JAVASCRIPT
  end

  def reorder_fetch_calls
    page.evaluate_script("window.__personTagFetchCalls || []").select do |call|
      call["path"].include?("/person_tags/reorder")
    end
  end

  def install_reorder_completion_marker
    page.execute_script(<<~JAVASCRIPT)
      const originalFetch = window.fetch.bind(window)
      window.fetch = (...args) => {
        const result = originalFetch(...args)
        if (String(args[0]).includes("/person_tags/reorder")) {
          result.finally(() => { document.body.dataset.personTagReorderComplete = "true" })
        }
        return result
      }
    JAVASCRIPT
  end

  def hold_reorder_fetch
    page.execute_script(<<~JAVASCRIPT)
      const originalFetch = window.fetch.bind(window)
      window.fetch = (...args) => {
        if (!String(args[0]).includes("/person_tags/reorder")) return originalFetch(...args)

        return new Promise((resolve) => {
          window.__resolvePersonTagReorder = resolve
        })
      }
    JAVASCRIPT
  end

  def resolve_held_reorder_fetch
    page.execute_script(<<~JAVASCRIPT)
      window.__resolvePersonTagReorder(
        new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { "Content-Type": "application/json" }
        })
      )
    JAVASCRIPT
  end

  def reject_first_reorder_fetch
    page.execute_script(<<~JAVASCRIPT)
      const originalFetch = window.fetch.bind(window)
      window.__personTagReorderAttempts = 0
      window.fetch = (...args) => {
        if (!String(args[0]).includes("/person_tags/reorder")) return originalFetch(...args)

        window.__personTagReorderAttempts += 1
        if (window.__personTagReorderAttempts === 1) {
          return Promise.resolve(
            new Response(JSON.stringify({ ok: false }), {
              status: 200,
              headers: { "Content-Type": "application/json" }
            })
          )
        }
        return originalFetch(...args)
      }
      window.alert = (message) => { document.body.dataset.lastAlert = message }
    JAVASCRIPT
  end
end
