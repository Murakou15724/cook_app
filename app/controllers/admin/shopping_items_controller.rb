module Admin
  class ShoppingItemsController < BaseController
    before_action :set_shopping_item, only: [:show, :edit, :update, :destroy]

    def index
      @shopping_items = ShoppingItem.includes(:user).order(:created_at)
    end

    def show
    end

    def edit
    end

    def update
      redirect_to admin_shopping_item_path(@shopping_item), notice: "管理者買い物項目更新は後続issueで実装します"
    end

    def destroy
      redirect_to admin_shopping_items_path, notice: "管理者買い物項目削除は後続issueで実装します"
    end

    private

    def set_shopping_item
      @shopping_item = ShoppingItem.find(params[:id])
    end
  end
end
