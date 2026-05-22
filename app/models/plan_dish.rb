class PlanDish < ApplicationRecord
  belongs_to :meal_plan
  has_many :dish_ingredients, dependent: :destroy
  has_many :cooking_records, foreign_key: :source_plan_dish_id, dependent: :destroy, inverse_of: :source_plan_dish

  before_validation :normalize_name

  validates :name, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :id) }

  private

  def normalize_name
    self.name = name.to_s.strip
  end
end
