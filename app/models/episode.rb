class Episode < ApplicationRecord
  belongs_to :title
  has_many :viewings

  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :title_id }

  # "3. Brigade", or just "Episode 3" when there's no real name (some shows name every episode
  # "Episode N", which would read "3. Episode 3"). A movie's one episode is just the movie.
  def label
    return title.full_name if title&.movie?

    placeholder = name.blank? || name.strip.casecmp?("Episode #{number}")
    placeholder ? "Episode #{number}" : "#{number}. #{name}"
  end
end
