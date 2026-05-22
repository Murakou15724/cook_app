class CreateCookAppCoreTables < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.integer :role, null: false, default: 0

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :role
    add_index :users, :created_at

    create_table :meal_plans do |t|
      t.references :user, null: false, foreign_key: true
      t.date :meal_date, null: false
      t.integer :meal_type, null: false
      t.boolean :migrated, null: false, default: false
      t.datetime :migrated_at

      t.timestamps
    end

    add_index :meal_plans, [:user_id, :meal_date, :meal_type], unique: true
    add_index :meal_plans, [:user_id, :migrated, :meal_date, :meal_type]
    add_index :meal_plans, :created_at

    create_table :plan_dishes do |t|
      t.references :meal_plan, null: false, foreign_key: true
      t.string :name, null: false
      t.text :memo
      t.boolean :eating_out, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :plan_dishes, :name
    add_index :plan_dishes, :eating_out
    add_index :plan_dishes, [:meal_plan_id, :position]
    add_index :plan_dishes, :created_at

    create_table :dish_ingredients do |t|
      t.references :plan_dish, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :add_to_shopping_list, null: false, default: true

      t.timestamps
    end

    add_index :dish_ingredients, :name
    add_index :dish_ingredients, :created_at

    create_table :shopping_items do |t|
      t.references :user, null: false, foreign_key: true
      t.references :dish_ingredient, foreign_key: true
      t.string :name, null: false
      t.boolean :manual, null: false, default: false
      t.boolean :purchased, null: false, default: false
      t.datetime :purchased_at

      t.timestamps
    end

    add_index :shopping_items, :name
    add_index :shopping_items, :manual
    add_index :shopping_items, :purchased
    add_index :shopping_items, :purchased_at
    add_index :shopping_items, [:user_id, :purchased, :manual, :created_at]
    add_index :shopping_items, :created_at

    create_table :cooking_records do |t|
      t.references :user, null: false, foreign_key: true
      t.references :source_meal_plan, null: false, foreign_key: { to_table: :meal_plans }
      t.references :source_plan_dish, null: false, foreign_key: { to_table: :plan_dishes }, index: { unique: true }
      t.string :name, null: false
      t.date :cooked_on, null: false
      t.integer :meal_type, null: false
      t.text :memo
      t.boolean :eating_out, null: false, default: false

      t.timestamps
    end

    add_index :cooking_records, :name
    add_index :cooking_records, :cooked_on
    add_index :cooking_records, :meal_type
    add_index :cooking_records, :eating_out
    add_index :cooking_records, [:user_id, :cooked_on, :meal_type]
    add_index :cooking_records, :created_at

    create_table :person_tags do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :default_selected, null: false, default: false

      t.timestamps
    end

    add_index :person_tags, [:user_id, :name], unique: true
    add_index :person_tags, [:user_id, :default_selected]
    add_index :person_tags, :created_at

    create_table :meal_plan_person_tags do |t|
      t.references :meal_plan, null: false, foreign_key: true
      t.references :person_tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :meal_plan_person_tags, [:meal_plan_id, :person_tag_id], unique: true
    add_index :meal_plan_person_tags, :created_at

    create_table :cooking_record_person_tags do |t|
      t.references :cooking_record, null: false, foreign_key: true
      t.references :person_tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :cooking_record_person_tags, [:cooking_record_id, :person_tag_id], unique: true
    add_index :cooking_record_person_tags, [:person_tag_id, :cooking_record_id]
    add_index :cooking_record_person_tags, :created_at
  end
end
