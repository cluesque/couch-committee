class Title < ApplicationRecord
  has_many :episodes, -> { order(:number) }, dependent: :destroy, inverse_of: :title
  has_many :list_entries

  enum :kind, { movie: 0, series: 1, book: 2, podcast: 3 }, validate: true

  validates :name, presence: true
  validates :season, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :season, presence: true, if: :series?
  validates :season, absence: true, if: :movie?
  validate :movie_has_exactly_one_episode, if: :movie?

  accepts_nested_attributes_for :episodes

  def full_name
    season ? "#{name}: Season #{season}" : name
  end

  private
    def movie_has_exactly_one_episode
      errors.add(:base, "A movie has exactly one episode") unless episodes.reject(&:marked_for_destruction?).one?
    end
end
