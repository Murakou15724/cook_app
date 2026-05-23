class UpdateDefaultNicknameFormat < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL.squish
      UPDATE users
      SET nickname = CONCAT('ユーザー', id)
      WHERE nickname = CONCAT('ユーザー:', id)
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE users
      SET nickname = CONCAT('ユーザー:', id)
      WHERE nickname = CONCAT('ユーザー', id)
    SQL
  end
end
