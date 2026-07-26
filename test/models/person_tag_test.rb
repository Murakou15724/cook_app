require "test_helper"

class PersonTagTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "tag-owner@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
  end

  test "normalizes name and requires presence" do
    tag = @user.person_tags.create!(name: "  家族  ")
    blank = @user.person_tags.new(name: "   ")

    assert_equal "家族", tag.name
    assert_not blank.valid?
  end

  test "prevents duplicate names per user but allows same name for different users" do
    @user.person_tags.create!(name: "家族")
    duplicate = @user.person_tags.new(name: "家族")
    other_user = User.create!(
      email: "other-tag-owner@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    other_tag = other_user.person_tags.new(name: "家族")

    assert_not duplicate.valid?
    assert other_tag.valid?
  end

  test "requires a non-negative integer sort order" do
    negative = @user.person_tags.new(name: "家族", sort_order: -1)
    decimal = @user.person_tags.new(name: "友人", sort_order: 1.5)

    assert_not negative.valid?
    assert_not decimal.valid?
  end

  test "new tags are appended and display order is stable across edits and deletes" do
    first = @user.person_tags.create!(name: "友人")
    second = @user.person_tags.create!(name: "家族")

    assert_equal [1000, 2000], [first.sort_order, second.sort_order]
    assert_equal [first, second], @user.person_tags.display_ordered.to_a

    first.update!(name: "知人", default_selected: true)
    assert_equal [first, second], @user.person_tags.display_ordered.to_a

    first.destroy!
    third = @user.person_tags.create!(name: "親族")
    assert_equal [second, third], @user.person_tags.display_ordered.to_a
    assert_equal 3000, third.sort_order
  end

  test "reorders a complete permutation and accepts canonical digit strings" do
    first = @user.person_tags.create!(name: "家族")
    second = @user.person_tags.create!(name: "友人")
    previous_updated_at = 1.day.ago
    first.update_column(:updated_at, previous_updated_at)
    second.update_column(:updated_at, previous_updated_at)

    locks = capture_lock_queries do
      PersonTag.reorder_for!(user: @user, ids: [second.id.to_s, first.id.to_s])
    end

    assert_equal [second, first], @user.person_tags.display_ordered.to_a
    assert_equal [1000, 2000], [second.reload.sort_order, first.reload.sort_order]
    assert_operator first.updated_at, :>, previous_updated_at
    assert_operator second.updated_at, :>, previous_updated_at
    assert_lock_order locks
  end

  test "rejects a non-permutation before changing any tag" do
    first = @user.person_tags.create!(name: "家族")
    second = @user.person_tags.create!(name: "友人")
    original = @user.person_tags.order(:id).pluck(:id, :sort_order, :updated_at)

    assert_raises(PersonTag::InvalidReorder) do
      PersonTag.reorder_for!(user: @user, ids: [second.id, second.id])
    end

    assert_equal original, @user.person_tags.order(:id).pluck(:id, :sort_order, :updated_at)
  end

  test "create and destroy lock the owner before tags ordered by id" do
    create_locks = capture_lock_queries do
      @user.person_tags.create!(name: "家族")
    end
    assert_lock_order create_locks

    tag = @user.person_tags.create!(name: "友人")
    destroy_locks = capture_lock_queries do
      tag.destroy!
    end
    assert_lock_order destroy_locks
  end

  private

  def capture_lock_queries
    queries = []
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      queries << payload[:sql] if payload[:sql].include?("FOR UPDATE")
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end

  def assert_lock_order(queries)
    user_lock_index = queries.index { |sql| sql.match?(/FROM [`"]?users[`"]?/i) }
    tag_lock_index = queries.index { |sql| sql.match?(/FROM [`"]?person_tags[`"]?/i) }

    assert user_lock_index, queries.inspect
    assert tag_lock_index, queries.inspect
    assert_operator user_lock_index, :<, tag_lock_index
    assert_match(/ORDER BY [`"]?person_tags[`"]?\.[`"]?id[`"]? ASC/i, queries[tag_lock_index])
  end
end
