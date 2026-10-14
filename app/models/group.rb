class Group < ApplicationRecord
  has_many :group_memberships, dependent: :destroy
  has_many :users, through: :group_memberships
  has_many :play_lists
  has_many :viewings

  validates :name, presence: true
end
