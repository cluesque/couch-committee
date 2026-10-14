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
