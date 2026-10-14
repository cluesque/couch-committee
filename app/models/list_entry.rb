class ListEntry < ApplicationRecord
  ACTIVE_STATES = %w[ not_started in_progress ].freeze

  belongs_to :play_list
  belongs_to :title
  has_many :viewings

  enum :state, { not_started: 0, in_progress: 1, watched: 2, cancelled: 3 }, validate: true

  scope :active, -> { where(state: ACTIVE_STATES) }

  validates :sequence, numericality: { only_integer: true }
  validates :title, uniqueness: { scope: :play_list, conditions: -> { active }, message: "is already on this playlist" },
    if: :active?

  def active?
    state.in?(ACTIVE_STATES)
  end
end
