class User < ApplicationRecord
  has_secure_password

  enum :role, { member: 0, admin: 1 }

  has_many :meal_plans, dependent: :destroy
  has_many :shopping_items, dependent: :destroy
  has_many :cooking_records, dependent: :destroy
  has_many :person_tags, dependent: :destroy

  before_validation :normalize_email
  before_destroy :ensure_another_admin_remains

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 6 }, allow_nil: true
  validates :password_confirmation, presence: true, if: -> { password.present? }
  validates :role, presence: true

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def ensure_another_admin_remains
    return unless admin?
    return if User.admin.where.not(id: id).exists?

    errors.add(:base, "最後の管理者は削除できません")
    throw :abort
  end
end
