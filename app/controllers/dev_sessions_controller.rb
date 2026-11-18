# Lets development (and tests) sign in as any email, so running the app doesn't need a Google
# OAuth client. Turned on by config.x.dev_sign_in, which only development and test set; anywhere
# else this is a 404.
class DevSessionsController < ApplicationController
  allow_unauthenticated_access only: :create
  before_action :require_dev_sign_in

  # Signs in as whoever has this email, even someone who signs in with Google (handy with a copy
  # of production data). Otherwise it's like a first Google sign-in: it claims an invited user or
  # creates a new one, and makes sure they have a Just Me list. It never sets a Google account ID,
  # so a later real Google sign-in with the same email still works.
  def create
    if user = find_or_create_user
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Sorry, that doesn't look like an email address."
    end
  end

  private
    def require_dev_sign_in
      head :not_found unless Rails.configuration.x.dev_sign_in
    end

    def find_or_create_user
      user = User.find_or_initialize_by(email: params[:email].to_s)
      user.display_name = params[:name].presence if user.display_name.blank?
      User.transaction do
        user.save!
        user.create_just_me_list unless user.lists.exists?(name: List::JUST_ME)
      end
      user
    rescue ActiveRecord::RecordInvalid
      nil
    end
end
