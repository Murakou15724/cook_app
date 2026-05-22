class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    @today = Date.current
    @meal_plans = current_user.meal_plans
                              .active
                              .where(meal_date: @today)
                              .includes(:person_tags, plan_dishes: :dish_ingredients)
                              .index_by(&:meal_type)
  end
end
