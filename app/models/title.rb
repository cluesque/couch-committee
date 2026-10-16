class Title < ApplicationRecord
  has_many :episodes, -> { order(:number) }, dependent: :destroy, inverse_of: :title
  has_many :list_entries

  enum :kind, { movie: 0, series: 1, book: 2, podcast: 3 }, validate: true

  validates :name, presence: true
  validates :season, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :season, presence: true, if: :series?
  validates :season, absence: true, if: :movie?
  validate :movie_has_exactly_one_episode, if: :movie?
  validate :episode_numbers_are_unique
  validates :tmdb_id, uniqueness: { scope: %i[ kind season ], message: "is already in the catalog" }, allow_nil: true

  accepts_nested_attributes_for :episodes

  # Case-insensitive on both SQLite (LIKE) and Postgres (ILIKE).
  scope :search, ->(query) { where(arel_table[:name].matches("%#{sanitize_sql_like(query)}%")).order(:name, :season) }

  def full_name
    season ? "#{name}: Season #{season}" : name
  end

  # A season links to its show on IMDb, which is where IMDb keeps seasons.
  def imdb_url
    "https://www.imdb.com/title/#{imdb_id}/" if imdb_id.present?
  end

  def tmdb_url
    return if tmdb_id.blank?

    series? ? "https://www.themoviedb.org/tv/#{tmdb_id}/season/#{season}" : "https://www.themoviedb.org/movie/#{tmdb_id}"
  end

  private
    def movie_has_exactly_one_episode
      errors.add(:base, "A movie has exactly one episode") unless episodes.reject(&:marked_for_destruction?).one?
    end

    # Episode's own uniqueness validation can't see unsaved siblings, e.g. in one season form.
    def episode_numbers_are_unique
      numbers = episodes.reject(&:marked_for_destruction?).filter_map(&:number)
      errors.add(:base, "Episode numbers must be unique") if numbers.uniq.size < numbers.size
    end
end
