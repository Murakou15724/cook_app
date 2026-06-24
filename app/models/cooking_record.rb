class CookingRecord < ApplicationRecord
  enum :meal_type, { lunch: 0, dinner: 1 }

  belongs_to :user
  belongs_to :source_meal_plan, class_name: "MealPlan", optional: true
  belongs_to :source_plan_dish, class_name: "PlanDish", optional: true
  has_many :cooking_record_person_tags, dependent: :destroy
  has_many :person_tags, through: :cooking_record_person_tags

  before_validation :normalize_name

  validates :name, presence: true
  validates :cooked_on, presence: true
  validates :meal_type, presence: true
  validates :source_plan_dish_id, uniqueness: true, allow_nil: true

  scope :newest_first, -> { order(cooked_on: :desc, meal_type: :asc, created_at: :desc) }

  private

  def normalize_name
    self.name = name.to_s.strip
  end
end
