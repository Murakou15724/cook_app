class AddNicknameToUsers < ActiveRecord::Migration[7.1]
  def up
    add_column :users, :nickname, :string
    add_index :users, :nickname

    execute <<~SQL.squish
      UPDATE users
      SET nickname = CONCAT('ユーザー', id)
      WHERE nickname IS NULL OR nickname = ''
    SQL
  end

  def down
    remove_index :users, :nickname
    remove_column :users, :nickname
  end
end
