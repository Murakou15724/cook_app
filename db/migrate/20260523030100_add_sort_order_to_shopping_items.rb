class AddSortOrderToShoppingItems < ActiveRecord::Migration[7.1]
  def change
    add_column :shopping_items, :sort_order, :integer, null: false, default: 0
    add_index :shopping_items, [:user_id, :purchased, :sort_order, :created_at]
  end
end
