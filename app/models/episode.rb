class Episode < ApplicationRecord
  belongs_to :title

  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :title_id }
end
