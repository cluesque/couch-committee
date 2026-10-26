class Tag < ApplicationRecord
  # Bootstrap's palette; each is drawn as a soft pill (see .tag-<color> in application.scss).
  COLORS = %w[ blue teal green yellow orange red pink purple gray ].freeze

  belongs_to :list
  has_many :list_entry_tags, dependent: :destroy
  has_many :list_entries, through: :list_entry_tags

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, length: { maximum: 20 },
    uniqueness: { scope: :list, case_sensitive: false, message: "is already a tag on this list" }
  validates :color, inclusion: { in: COLORS }

  # For a new tag on the list: the first color it isn't using yet.
  def self.next_color(list)
    (COLORS - list.tags.pluck(:color)).first || COLORS.first
  end
end
