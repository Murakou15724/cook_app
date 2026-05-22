class ShoppingItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_shopping_item, only: [:destroy, :toggle_purchased]

  def index
    @shopping_items = current_user.shopping_items.order(:purchased, :manual, :created_at)
    @unpurchased_items = @shopping_items.reject(&:purchased?)
    @purchased_items = @shopping_items.select(&:purchased?)
  end

  def create
    redirect_to shopping_items_path, notice: "手動追加は後続issueで実装します"
  end

  def destroy
    redirect_to shopping_items_path, notice: "削除は後続issueで実装します"
  end

  def toggle_purchased
    redirect_to shopping_items_path, notice: "購入済み切替は後続issueで実装します"
  end

  def destroy_purchased
    redirect_to shopping_items_path, notice: "購入済み一括削除は後続issueで実装します"
  end

  private

  def set_shopping_item
    @shopping_item = current_user.shopping_items.find(params[:id])
  end
end
