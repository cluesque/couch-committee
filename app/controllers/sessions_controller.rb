class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  def new
    redirect_to root_path if authenticated?
  end

  # google_sign_in redirects here after the OAuth round-trip, with the outcome in the flash.
  def create
    if user = authenticate_with_google
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Sorry, we couldn't sign you in with Google."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "You've been signed out.", status: :see_other
  end

  private
    def authenticate_with_google
      response = flash[:google_sign_in].to_h

      if id_token = response["id_token"]
        User.from_google(GoogleSignIn::Identity.new(id_token))
      elsif error = response["error"]
        logger.info "Google sign-in failed: #{error}"
        nil
      end
    rescue GoogleSignIn::Identity::ValidationError => error
      logger.warn "Google ID token rejected: #{error.message}"
      nil
    end
end
