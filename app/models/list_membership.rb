class ListMembership < ApplicationRecord
  belongs_to :list
  belongs_to :user

  validates :user, uniqueness: { scope: :list, message: "is already on this list" }
end
