class DishIngredient < ApplicationRecord
  belongs_to :plan_dish
  has_many :shopping_items, dependent: :destroy

  before_validation :normalize_name

  validates :name, presence: true

  private

  def normalize_name
    self.name = name.to_s.strip
  end
end
