class MealPlanPersonTag < ApplicationRecord
  belongs_to :meal_plan
  belongs_to :person_tag

  validates :person_tag_id, uniqueness: { scope: :meal_plan_id }
  validate :person_tag_belongs_to_same_user

  private

  def person_tag_belongs_to_same_user
    return if meal_plan.blank? || person_tag.blank?
    return if meal_plan.user_id == person_tag.user_id

    errors.add(:person_tag, "は同じユーザーのタグを選択してください")
  end
end
