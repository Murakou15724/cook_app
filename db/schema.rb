# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_05_24_020100) do
  create_table "cooking_record_person_tags", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "cooking_record_id", null: false
    t.bigint "person_tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cooking_record_id", "person_tag_id"], name: "idx_on_cooking_record_id_person_tag_id_8f9925af70", unique: true
    t.index ["cooking_record_id"], name: "index_cooking_record_person_tags_on_cooking_record_id"
    t.index ["created_at"], name: "index_cooking_record_person_tags_on_created_at"
    t.index ["person_tag_id", "cooking_record_id"], name: "idx_on_person_tag_id_cooking_record_id_64953f60ea"
    t.index ["person_tag_id"], name: "index_cooking_record_person_tags_on_person_tag_id"
  end

  create_table "cooking_records", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "source_meal_plan_id"
    t.bigint "source_plan_dish_id"
    t.string "name", null: false
    t.date "cooked_on", null: false
    t.integer "meal_type", null: false
    t.text "memo"
    t.boolean "eating_out", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cooked_on"], name: "index_cooking_records_on_cooked_on"
    t.index ["created_at"], name: "index_cooking_records_on_created_at"
    t.index ["eating_out"], name: "index_cooking_records_on_eating_out"
    t.index ["meal_type"], name: "index_cooking_records_on_meal_type"
    t.index ["name"], name: "index_cooking_records_on_name"
    t.index ["source_meal_plan_id"], name: "index_cooking_records_on_source_meal_plan_id"
    t.index ["source_plan_dish_id"], name: "index_cooking_records_on_source_plan_dish_id", unique: true
    t.index ["user_id", "cooked_on", "meal_type"], name: "index_cooking_records_on_user_id_and_cooked_on_and_meal_type"
    t.index ["user_id"], name: "index_cooking_records_on_user_id"
    t.check_constraint "`meal_type` in (0,1)", name: "chk_cooking_records_meal_type"
    t.check_constraint "char_length(trim(`name`)) > 0", name: "chk_cooking_records_name_present"
  end

  create_table "dish_ingredients", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "plan_dish_id", null: false
    t.string "name", null: false
    t.boolean "add_to_shopping_list", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_dish_ingredients_on_created_at"
    t.index ["name"], name: "index_dish_ingredients_on_name"
    t.index ["plan_dish_id"], name: "index_dish_ingredients_on_plan_dish_id"
    t.check_constraint "char_length(trim(`name`)) > 0", name: "chk_dish_ingredients_name_present"
  end

  create_table "meal_plan_person_tags", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "meal_plan_id", null: false
    t.bigint "person_tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_meal_plan_person_tags_on_created_at"
    t.index ["meal_plan_id", "person_tag_id"], name: "index_meal_plan_person_tags_on_meal_plan_id_and_person_tag_id", unique: true
    t.index ["meal_plan_id"], name: "index_meal_plan_person_tags_on_meal_plan_id"
    t.index ["person_tag_id"], name: "index_meal_plan_person_tags_on_person_tag_id"
  end

  create_table "meal_plans", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "meal_date", null: false
    t.integer "meal_type", null: false
    t.boolean "migrated", default: false, null: false
    t.datetime "migrated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_meal_plans_on_created_at"
    t.index ["user_id", "meal_date", "meal_type"], name: "index_meal_plans_on_user_id_and_meal_date_and_meal_type", unique: true
    t.index ["user_id", "migrated", "meal_date", "meal_type"], name: "idx_on_user_id_migrated_meal_date_meal_type_1fc5b26fe4"
    t.index ["user_id"], name: "index_meal_plans_on_user_id"
    t.check_constraint "((`migrated` = 0) and (`migrated_at` is null)) or ((`migrated` = 1) and (`migrated_at` is not null))", name: "chk_meal_plans_migrated_at"
    t.check_constraint "`meal_type` in (0,1)", name: "chk_meal_plans_meal_type"
  end

  create_table "passkeys", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "external_id", null: false
    t.text "public_key", null: false
    t.string "nickname", null: false
    t.integer "sign_count", default: 0, null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_passkeys_on_external_id", unique: true
    t.index ["user_id"], name: "index_passkeys_on_user_id"
  end

  create_table "person_tags", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.boolean "default_selected", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_person_tags_on_created_at"
    t.index ["user_id", "default_selected"], name: "index_person_tags_on_user_id_and_default_selected"
    t.index ["user_id", "name"], name: "index_person_tags_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_person_tags_on_user_id"
    t.check_constraint "char_length(trim(`name`)) > 0", name: "chk_person_tags_name_present"
  end

  create_table "plan_dishes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "meal_plan_id", null: false
    t.string "name", null: false
    t.text "memo"
    t.boolean "eating_out", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_plan_dishes_on_created_at"
    t.index ["eating_out"], name: "index_plan_dishes_on_eating_out"
    t.index ["meal_plan_id", "position"], name: "index_plan_dishes_on_meal_plan_id_and_position"
    t.index ["meal_plan_id"], name: "index_plan_dishes_on_meal_plan_id"
    t.index ["name"], name: "index_plan_dishes_on_name"
    t.check_constraint "`position` >= 0", name: "chk_plan_dishes_position"
    t.check_constraint "char_length(trim(`name`)) > 0", name: "chk_plan_dishes_name_present"
  end

  create_table "shopping_items", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "dish_ingredient_id"
    t.string "name", null: false
    t.boolean "manual", default: false, null: false
    t.boolean "purchased", default: false, null: false
    t.datetime "purchased_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "sort_order", default: 0, null: false
    t.index ["created_at"], name: "index_shopping_items_on_created_at"
    t.index ["dish_ingredient_id"], name: "index_shopping_items_on_dish_ingredient_id"
    t.index ["manual"], name: "index_shopping_items_on_manual"
    t.index ["name"], name: "index_shopping_items_on_name"
    t.index ["purchased"], name: "index_shopping_items_on_purchased"
    t.index ["purchased_at"], name: "index_shopping_items_on_purchased_at"
    t.index ["user_id", "purchased", "manual", "created_at"], name: "idx_on_user_id_purchased_manual_created_at_b305ea790a"
    t.index ["user_id", "purchased", "sort_order", "created_at"], name: "idx_on_user_id_purchased_sort_order_created_at_45c3b7057f"
    t.index ["user_id"], name: "index_shopping_items_on_user_id"
    t.check_constraint "((`manual` = 1) and (`dish_ingredient_id` is null)) or ((`manual` = 0) and (`dish_ingredient_id` is not null))", name: "chk_shopping_items_manual_source"
    t.check_constraint "((`purchased` = 0) and (`purchased_at` is null)) or ((`purchased` = 1) and (`purchased_at` is not null))", name: "chk_shopping_items_purchased_at"
    t.check_constraint "char_length(trim(`name`)) > 0", name: "chk_shopping_items_name_present"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "nickname"
    t.string "webauthn_id"
    t.index ["created_at"], name: "index_users_on_created_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["nickname"], name: "index_users_on_nickname"
    t.index ["role"], name: "index_users_on_role"
    t.index ["webauthn_id"], name: "index_users_on_webauthn_id", unique: true
    t.check_constraint "`role` in (0,1)", name: "chk_users_role"
  end

  add_foreign_key "cooking_record_person_tags", "cooking_records"
  add_foreign_key "cooking_record_person_tags", "person_tags"
  add_foreign_key "cooking_records", "meal_plans", column: "source_meal_plan_id"
  add_foreign_key "cooking_records", "plan_dishes", column: "source_plan_dish_id"
  add_foreign_key "cooking_records", "users"
  add_foreign_key "dish_ingredients", "plan_dishes"
  add_foreign_key "meal_plan_person_tags", "meal_plans"
  add_foreign_key "meal_plan_person_tags", "person_tags"
  add_foreign_key "meal_plans", "users"
  add_foreign_key "passkeys", "users"
  add_foreign_key "person_tags", "users"
  add_foreign_key "plan_dishes", "meal_plans"
  add_foreign_key "shopping_items", "dish_ingredients"
  add_foreign_key "shopping_items", "users"
end
