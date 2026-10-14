module SignInHelper
  # Runs the full google_sign_in round-trip, with FakeGoogle standing in for Google.
  def sign_in_with_google(**claims)
    post google_sign_in.authorization_url, params: { proceed_to: google_session_url }
    state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")

    get google_sign_in.callback_url, params: { code: FakeGoogle.authorization_code_for(**claims), state: state }
    follow_redirect!
  end

  def sign_in_as(user)
    sign_in_with_google(sub: user.google_id, email: user.email, name: user.display_name)
  end
end
