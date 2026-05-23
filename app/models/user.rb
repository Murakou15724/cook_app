class User < ApplicationRecord
  has_secure_password

  enum :role, { member: 0, admin: 1 }

  has_many :meal_plans, dependent: :destroy
  has_many :shopping_items, dependent: :destroy
  has_many :cooking_records, dependent: :destroy
  has_many :person_tags, dependent: :destroy

  before_validation :normalize_email
  before_validation :normalize_nickname
  after_create :assign_default_nickname!
  before_destroy :ensure_another_admin_remains

  validates :email, presence: true,
                    format: { with: /\A.*@.*\z/, message: "は@を含めてください" },
                    uniqueness: { case_sensitive: false }
  validates :password,
            length: { in: 6..20 },
            format: { with: /\A(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]+\z/, message: "は英字と数字のみを使い、英字と数字の両方を含めてください" },
            allow_nil: true
  validates :password_confirmation, presence: true, if: -> { password.present? }
  validates :role, presence: true
  validates :nickname, length: { maximum: 20 }, allow_blank: true

  def display_nickname
    nickname.presence || default_nickname
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def normalize_nickname
    normalized = nickname.to_s.strip.presence
    self.nickname = normalized || (persisted? ? default_nickname : nil)
  end

  def assign_default_nickname!
    return if nickname.present?

    update_column(:nickname, default_nickname)
  end

  def default_nickname
    "ユーザー#{id}"
  end

  def ensure_another_admin_remains
    return unless admin?
    return if User.admin.where.not(id: id).exists?

    errors.add(:base, "最後の管理者は削除できません")
    throw :abort
  end
end
