class PlayList < ApplicationRecord
  belongs_to :group
  has_many :list_entries

  validates :name, presence: true
end
