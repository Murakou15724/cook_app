class ApplicationController < ActionController::Base
  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id].present?
  end

  def logged_in?
    current_user.present?
  end

  def authenticate_user!
    return if logged_in?

    redirect_to login_path, alert: "ログインしてください"
  end

  def require_no_login!
    redirect_to root_path if logged_in?
  end

  def require_admin!
    return if current_user&.admin?

    redirect_to forbidden_path, alert: "管理者権限が必要です"
  end

  def migrate_past_meal_plans!
    return unless current_user

    current_user.meal_plans.active
                .where(meal_date: ...Date.current)
                .includes(:person_tags, plan_dishes: :dish_ingredients)
                .find_each do |meal_plan|
      ActiveRecord::Base.transaction do
        meal_plan.plan_dishes.ordered.each do |dish|
          next if current_user.cooking_records.exists?(source_plan_dish_id: dish.id)

          record = current_user.cooking_records.create!(
            source_meal_plan: meal_plan,
            source_plan_dish: dish,
            name: dish.name,
            cooked_on: meal_plan.meal_date,
            meal_type: meal_plan.meal_type,
            memo: dish.memo,
            eating_out: dish.eating_out?
          )
          record.person_tag_ids = meal_plan.person_tag_ids
        end

        meal_plan.update!(migrated: true, migrated_at: Time.current)
      end
    end
  end
end
