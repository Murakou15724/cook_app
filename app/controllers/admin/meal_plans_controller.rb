module Admin
  class MealPlansController < BaseController
    before_action :set_meal_plan, only: [:show, :edit, :update, :destroy]

    def index
      @meal_plans = MealPlan.includes(:user, :plan_dishes).ordered
    end

    def show
    end

    def edit
    end

    def update
      redirect_to admin_meal_plan_path(@meal_plan), notice: "管理者献立更新は後続issueで実装します"
    end

    def destroy
      redirect_to admin_meal_plans_path, notice: "管理者献立削除は後続issueで実装します"
    end

    private

    def set_meal_plan
      @meal_plan = MealPlan.find(params[:id])
    end
  end
end
