module Admin
  class ShoppingItemsController < BaseController
    before_action :set_shopping_item, only: [:destroy]

    def index
      @shopping_items = ShoppingItem.includes(:user).order(:created_at)
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
