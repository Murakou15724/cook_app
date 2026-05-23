module Admin
  class UsersController < BaseController
    before_action :set_user, only: [:show, :destroy, :meal_plans, :shopping_items, :cooking_records]

    def index
      @users = User.order(:created_at)
    end

    def show
    end

    def meal_plans
      @query = params[:q].to_s.strip
      @meal_plans = @user.meal_plans
                         .active
                         .includes(:person_tags, plan_dishes: :dish_ingredients)
                         .ordered
      return if @query.blank?

      keyword = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      @meal_plans = @meal_plans
                    .joins(:plan_dishes)
                    .where("plan_dishes.name LIKE :keyword OR plan_dishes.memo LIKE :keyword", keyword: keyword)
                    .distinct
    end

    def shopping_items
      @query = params[:q].to_s.strip
      @shopping_items = @user.shopping_items
                             .includes(dish_ingredient: { plan_dish: :meal_plan })
                             .display_ordered
      return if @query.blank?

      keyword = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      @shopping_items = @shopping_items.where("shopping_items.name LIKE ?", keyword)
    end

    def cooking_records
      @query = params[:q].to_s.strip
      @cooking_records = @user.cooking_records.newest_first.includes(:person_tags)
      return if @query.blank?

      keyword = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      matched = @cooking_records.where("cooking_records.name LIKE :keyword OR cooking_records.memo LIKE :keyword", keyword: keyword)
      @cooking_records = if @query == "外" || @query.include?("外食")
                           @cooking_records.where(id: matched.select(:id)).or(@cooking_records.where(eating_out: true))
                         else
                           matched
                         end
    end

    def destroy
      if @user.destroy
        redirect_to admin_users_path, notice: "ユーザーを削除しました"
      else
        redirect_to admin_users_path, alert: @user.errors.full_messages.to_sentence
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end
  end
end
