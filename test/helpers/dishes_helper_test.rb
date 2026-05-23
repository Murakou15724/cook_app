require "test_helper"

class DishesHelperTest < ActiveSupport::TestCase
  include DishesHelper

  test "returns the first matching icon by priority" do
    assert_equal "🍛", dish_icon("チキンカレー")
    assert_equal "🍖", dish_icon("肉じゃが")
    assert_equal "🥢", dish_icon("麻婆豆腐")
    assert_equal "🥗", dish_icon("サラダ")
    assert_equal "🍽️", dish_icon("不明料理")
  end
end
