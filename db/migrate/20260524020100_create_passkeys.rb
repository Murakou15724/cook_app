class CreatePasskeys < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :webauthn_id, :string

    reversible do |dir|
      dir.up do
        User.reset_column_information
        User.where(webauthn_id: [nil, ""]).find_each do |user|
          user.update_columns(webauthn_id: WebAuthn.generate_user_id)
        end
      end
    end

    add_index :users, :webauthn_id, unique: true

    create_table :passkeys do |t|
      t.references :user, null: false, foreign_key: true
      t.string :external_id, null: false
      t.text :public_key, null: false
      t.string :nickname, null: false
      t.integer :sign_count, null: false, default: 0
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :passkeys, :external_id, unique: true
  end
end
