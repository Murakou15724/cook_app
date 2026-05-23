class ShoppingItem < ApplicationRecord
  belongs_to :user
  belongs_to :dish_ingredient, optional: true
  has_one :plan_dish, through: :dish_ingredient
  has_one :meal_plan, through: :plan_dish

  before_validation :normalize_name
  before_validation :sync_purchased_at
  before_validation :assign_sort_order, on: :create

  validates :name, presence: true
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :manual_item_source_consistency

  scope :unpurchased, -> { where(purchased: false) }
  scope :purchased, -> { where(purchased: true) }
  scope :manual_items, -> { where(manual: true) }
  scope :meal_plan_items, -> { where(manual: false) }
  scope :display_ordered, -> { order(:purchased, :sort_order, :created_at, :id) }

  private

  def normalize_name
    self.name = name.to_s.strip
  end

  def sync_purchased_at
    self.purchased_at = Time.current if purchased? && purchased_at.blank?
    self.purchased_at = nil unless purchased?
  end

  def assign_sort_order
    return if sort_order.to_i.positive? || user.blank?

    self.sort_order = user.shopping_items.maximum(:sort_order).to_i + 1000
  end

  def manual_item_source_consistency
    if manual? && dish_ingredient_id.present?
      errors.add(:dish_ingredient, "は手動追加項目には設定できません")
    elsif !manual? && dish_ingredient_id.blank?
      errors.add(:dish_ingredient, "を設定してください")
    end
  end
end
