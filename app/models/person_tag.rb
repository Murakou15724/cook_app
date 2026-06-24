class PersonTag < ApplicationRecord
  belongs_to :user
  has_many :meal_plan_person_tags, dependent: :destroy
  has_many :meal_plans, through: :meal_plan_person_tags
  has_many :cooking_record_person_tags, dependent: :destroy
  has_many :cooking_records, through: :cooking_record_person_tags

  before_validation :normalize_name

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }

  private

  def normalize_name
    self.name = name.to_s.strip
  end
end
