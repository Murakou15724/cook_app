class AddSortOrderToPersonTags < ActiveRecord::Migration[7.1]
  SORT_ORDER_STEP = 1000

  def up
    add_column :person_tags, :sort_order, :integer, null: false, default: 0

    person_tag_class = Class.new(ActiveRecord::Base) do
      self.table_name = "person_tags"
    end
    person_tag_class.reset_column_information

    positions_by_user = Hash.new(0)
    person_tag_class.order(:user_id, :name, :id).each do |person_tag|
      positions_by_user[person_tag.user_id] += SORT_ORDER_STEP
      person_tag.update_columns(sort_order: positions_by_user[person_tag.user_id])
    end

    add_check_constraint :person_tags,
                         "sort_order >= 0",
                         name: "chk_person_tags_sort_order_non_negative"
    add_index :person_tags, [:user_id, :sort_order, :id]
  end

  def down
    remove_index :person_tags, column: [:user_id, :sort_order, :id]
    remove_check_constraint :person_tags, name: "chk_person_tags_sort_order_non_negative"
    remove_column :person_tags, :sort_order
  end
end
