class Episode < ApplicationRecord
  belongs_to :title
  has_many :viewings

  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :title_id }
end
