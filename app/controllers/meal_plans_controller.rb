class MealPlansController < ApplicationController
  before_action :authenticate_user!
  before_action :set_meal_plan, only: [:edit, :update, :destroy, :move_dish]

  def index
    @meal_plans = current_user.meal_plans.active.today_or_future.includes(:person_tags, :plan_dishes).ordered
  end

  def new
    @meal_plan = current_user.meal_plans.new(meal_date: Date.current)
    @person_tags = current_user.person_tags.order(:name)
  end

  def create
    redirect_to meal_plans_path, notice: "献立保存は後続issueで実装します"
  end

  def edit
    @person_tags = current_user.person_tags.order(:name)
  end

  def update
    redirect_to meal_plans_path, notice: "献立更新は後続issueで実装します"
  end

  def destroy
    redirect_to meal_plans_path, notice: "献立削除は後続issueで実装します"
  end

  def move_dish
    redirect_to edit_meal_plan_path(@meal_plan), notice: "並び替えは後続issueで実装します"
  end

  private

  def set_meal_plan
    @meal_plan = current_user.meal_plans.find(params[:id])
  end
end
