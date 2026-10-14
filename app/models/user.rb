class User < ApplicationRecord
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true
  validates :google_id, uniqueness: true, allow_nil: true

  def name
    display_name.presence || email
  end
end
