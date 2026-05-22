class ShoppingItem < ApplicationRecord
  belongs_to :user
  belongs_to :dish_ingredient, optional: true

  before_validation :normalize_name
  before_validation :sync_purchased_at

  validates :name, presence: true
  validate :manual_item_source_consistency

  private

  def normalize_name
    self.name = name.to_s.strip
  end

  def sync_purchased_at
    self.purchased_at = Time.current if purchased? && purchased_at.blank?
    self.purchased_at = nil unless purchased?
  end

  def manual_item_source_consistency
    if manual? && dish_ingredient_id.present?
      errors.add(:dish_ingredient, "は手動追加項目には設定できません")
    elsif !manual? && dish_ingredient_id.blank?
      errors.add(:dish_ingredient, "を設定してください")
    end
  end
end
