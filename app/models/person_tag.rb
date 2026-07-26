class PersonTag < ApplicationRecord
  SORT_ORDER_STEP = 1000

  class InvalidReorder < StandardError; end

  belongs_to :user
  has_many :meal_plan_person_tags, dependent: :destroy
  has_many :meal_plans, through: :meal_plan_person_tags
  has_many :cooking_record_person_tags, dependent: :destroy
  has_many :cooking_records, through: :cooking_record_person_tags

  before_validation :normalize_name
  before_create :assign_sort_order_at_end
  around_destroy :lock_owner_and_tags

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :display_ordered, -> { order(:sort_order, :id) }

  class << self
    def reorder_for!(user:, ids:)
      normalized_ids = normalize_reorder_ids(ids)
      raise InvalidReorder unless normalized_ids

      transaction do
        user.lock!
        tags = user.person_tags.order(:id).lock.to_a
        raise InvalidReorder unless normalized_ids.sort == tags.map(&:id)

        tags_by_id = tags.index_by(&:id)
        updated_at = Time.current
        normalized_ids.each_with_index do |id, index|
          update_reordered_tag!(
            tags_by_id.fetch(id),
            sort_order: (index + 1) * SORT_ORDER_STEP,
            updated_at: updated_at
          )
        end
      end
    end

    private

    def normalize_reorder_ids(ids)
      return unless ids.is_a?(Array)

      ids.map do |id|
        case id
        when Integer
          return unless id.positive?

          id
        when String
          return unless id.match?(/\A[1-9]\d*\z/)

          id.to_i
        else
          return
        end
      end
    end

    def update_reordered_tag!(tag, sort_order:, updated_at:)
      tag.update!(sort_order: sort_order, updated_at: updated_at)
    end
  end

  private

  def normalize_name
    self.name = name.to_s.strip
  end

  def assign_sort_order_at_end
    user.lock!
    tags = user.person_tags.order(:id).lock.to_a
    self.sort_order = tags.map(&:sort_order).max.to_i + SORT_ORDER_STEP
  end

  def lock_owner_and_tags
    user.lock!
    user.person_tags.order(:id).lock.load
    yield
  end
end
