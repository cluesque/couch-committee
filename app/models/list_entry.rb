class ListEntry < ApplicationRecord
  ACTIVE_STATES = %w[ not_started in_progress ].freeze

  belongs_to :list
  belongs_to :title
  has_many :viewings

  enum :state, { not_started: 0, in_progress: 1, watched: 2, cancelled: 3 }, validate: true

  scope :active, -> { where(state: ACTIVE_STATES) }

  # Why it's on the list, in the words of whoever added it. Optional.
  normalizes :recommendation, with: ->(text) { text.squish.presence }

  validates :sequence, numericality: { only_integer: true }
  validates :cancelled_at, presence: true, if: :cancelled?
  validates :recommendation, length: { maximum: 500 }
  validates :title, uniqueness: { scope: :list, conditions: -> { active }, message: "is already on this list" },
    if: :active?

  def active?
    state.in?(ACTIVE_STATES)
  end

  # "We decided not to watch this", as opposed to finishing it. The entry stays, with its note, in
  # the list's history.
  def cancel(note: nil)
    update(state: :cancelled, cancelled_at: Time.current, cancel_note: note.presence)
  end

  # Only this entry's viewings count, so a rewatch starts from the first episode again.
  def remaining_episodes
    title.episodes.reject { |episode| viewed?(episode) }
  end

  def viewed?(episode)
    viewings.any? { |viewing| viewing.episode_id == episode.id }
  end

  def next_episode
    remaining_episodes.first
  end

  def last_viewed_on
    viewings.map(&:date).max
  end

  # Nothing left to watch is out yet. An episode without a date is assumed to be available.
  def upcoming?(today = Date.current)
    remaining = remaining_episodes
    remaining.any? && remaining.all? { |episode| episode.available_on&.after?(today) }
  end
end
