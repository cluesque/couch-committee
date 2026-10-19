class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :list_memberships, dependent: :destroy
  # Deleted lists are hidden everywhere, except to bring one back.
  has_many :lists, -> { kept }, through: :list_memberships
  has_many :deleted_lists, -> { deleted }, through: :list_memberships, source: :list

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
    transaction do
      user.save!
      user.create_just_me_list
    end
    user
  end
  private_class_method :claim_or_create_from_google

  # Everyone starts with a list of their own, on first sign-in.
  def create_just_me_list
    List.create!(name: "Just Me").tap { |list| list.list_memberships.create!(user: self) }
  end

  def name
    display_name.presence || email
  end
end
