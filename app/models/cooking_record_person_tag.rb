class CookingRecordPersonTag < ApplicationRecord
  belongs_to :cooking_record
  belongs_to :person_tag

  validates :person_tag_id, uniqueness: { scope: :cooking_record_id }
  validate :person_tag_belongs_to_same_user

  private

  def person_tag_belongs_to_same_user
    return if cooking_record.blank? || person_tag.blank?
    return if cooking_record.user_id == person_tag.user_id

    errors.add(:person_tag, "は同じユーザーのタグを選択してください")
  end
end
