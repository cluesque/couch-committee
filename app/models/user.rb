class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :group_memberships, dependent: :destroy
  has_many :groups, through: :group_memberships
  has_many :play_lists, through: :groups

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :google_id, uniqueness: true, allow_nil: true

  # Returns nil when the identity can't be trusted to sign in as anyone.
  def self.from_google(identity)
    return unless identity.email_verified?

    find_by(google_id: identity.user_id) || claim_or_create_from_google(identity)
  end

  def self.claim_or_create_from_google(identity)
    user = find_or_initialize_by(email: identity.email_address)
    # This email already belongs to a different Google account.
    return if user.google_id.present?

    user.google_id = identity.user_id
    user.display_name = identity.name if user.display_name.blank?
    user.save!
    user
  end
  private_class_method :claim_or_create_from_google

  def name
    display_name.presence || email
  end
end
