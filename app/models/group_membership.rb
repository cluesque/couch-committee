class GroupMembership < ApplicationRecord
  belongs_to :group
  belongs_to :user

  validates :user, uniqueness: { scope: :group, message: "is already a member" }
end
