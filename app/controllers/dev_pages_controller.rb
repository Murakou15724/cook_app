class DevPagesController < ApplicationController
  before_action :authenticate_user!

  def index
    @meal_plan = current_user.meal_plans.first
    @cooking_record = current_user.cooking_records.first
    @person_tag = current_user.person_tags.first
    @shopping_item = current_user.shopping_items.first
  end
end
