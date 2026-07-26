require "test_helper"

class PersonTagOrderMigrationTest < ActiveSupport::TestCase
  test "person tags have the persisted order column constraint and covering index" do
    column = PersonTag.columns_hash.fetch("sort_order")
    assert_equal :integer, column.type
    assert_not column.null
    assert_equal 0, column.default.to_i

    index = PersonTag.connection.indexes(:person_tags).find do |candidate|
      candidate.columns == ["user_id", "sort_order", "id"]
    end
    assert index

    constraint = PersonTag.connection.check_constraints(:person_tags).find do |candidate|
      candidate.name == "chk_person_tags_sort_order_non_negative"
    end
    assert constraint
    assert_match(/sort_order.*>=.*0/i, constraint.expression)
  end
end
