class Title < ApplicationRecord
  has_many :episodes, -> { order(:number) }, dependent: :destroy, inverse_of: :title

  enum :kind, { movie: 0, series: 1, book: 2, podcast: 3 }, validate: true

  validates :name, presence: true
  validates :season, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :season, presence: true, if: :series?
  validates :season, absence: true, if: :movie?
end
