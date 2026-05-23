class MealPlan < ApplicationRecord
  enum :meal_type, { lunch: 0, dinner: 1 }

  belongs_to :user
  has_many :plan_dishes, dependent: :destroy
  has_many :meal_plan_person_tags, dependent: :destroy
  has_many :person_tags, through: :meal_plan_person_tags
  has_many :cooking_records, foreign_key: :source_meal_plan_id, dependent: :destroy, inverse_of: :source_meal_plan

  validates :meal_date, presence: true
  validates :meal_type, presence: true, uniqueness: { scope: [:user_id, :meal_date] }
  validate :migrated_at_matches_migrated_state

  scope :active, -> { where(migrated: false) }
  scope :today_or_future, -> { where(meal_date: Date.current..) }
  scope :ordered, -> { order(:meal_date, :meal_type) }

  private

  def migrated_at_matches_migrated_state
    errors.add(:migrated_at, "を設定してください") if migrated? && migrated_at.blank?
    errors.add(:migrated_at, "は移行済みの場合のみ設定できます") if !migrated? && migrated_at.present?
  end

end
