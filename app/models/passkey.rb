class Passkey < ApplicationRecord
  belongs_to :user

  before_validation :normalize_nickname

  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true
  validates :nickname, presence: true, length: { maximum: 40 }
  validates :sign_count, numericality: { greater_than_or_equal_to: 0 }

  private

  def normalize_nickname
    self.nickname = nickname.to_s.strip.presence || "パスキー"
  end
end
