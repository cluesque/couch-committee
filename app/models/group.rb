class Group < ApplicationRecord
  has_many :group_memberships, dependent: :destroy
  has_many :users, through: :group_memberships
  has_many :play_lists
  has_many :viewings

  validates :name, presence: true

  # There's no pending-invite state: someone not yet signed up gets a User with just their email,
  # which they claim on first Google sign-in.
  def invite(email)
    transaction do
      group_memberships.create!(user: User.find_or_create_by!(email: email))
    end
  end
end
