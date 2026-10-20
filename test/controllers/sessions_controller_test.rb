require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "signed-out visitors are sent to the sign-in page" do
    get root_path

    assert_redirected_to new_session_path
  end

  test "sign-in page offers Google sign-in" do
    get new_session_path

    assert_response :success
    assert_select "form[action=?] button", google_sign_in.authorization_path, text: "Sign in with Google"
  end

  test "signing in with Google creates the user, who's welcomed on the way Home" do
    assert_difference [ "User.count", "Session.count" ], 1 do
      sign_in_with_google(sub: "g-1", email: "pat@example.com", name: "Pat")
    end

    assert_redirected_to root_url
    follow_redirect!
    assert_redirected_to welcome_path
    follow_redirect!
    assert_select "nav", text: /Pat/
    assert_select "h1", "Welcome, Pat!"
  end

  test "signing in returns to the page originally requested" do
    get root_path(from: "bookmark")

    sign_in_as create(:user)

    assert_redirected_to root_url(from: "bookmark")
  end

  test "an already signed-in user skips the sign-in page" do
    sign_in_as create(:user)

    get new_session_path

    assert_redirected_to root_path
  end

  test "declining at Google is refused" do
    post google_sign_in.authorization_url, params: { proceed_to: google_session_url }
    get google_sign_in.callback_url, params: { error: "access_denied", state: oauth_state }
    follow_redirect!

    assert_sign_in_refused
  end

  test "an unverified Google email is refused" do
    sign_in_with_google(sub: "g-1", email: "pat@example.com", email_verified: false)

    assert_sign_in_refused
  end

  test "an ID token that fails verification is refused" do
    post google_sign_in.authorization_url, params: { proceed_to: google_session_url }
    get google_sign_in.callback_url, params: { code: "never-issued-by-google", state: oauth_state }
    follow_redirect!

    assert_sign_in_refused
  end

  test "visiting the Google return URL directly is refused" do
    get google_session_path

    assert_sign_in_refused
  end

  test "signing out ends the session" do
    sign_in_as create(:user)

    assert_difference "Session.count", -1 do
      delete session_path
    end
    assert_redirected_to new_session_path

    get root_path
    assert_redirected_to new_session_path
  end

  private
    def oauth_state
      Rack::Utils.parse_query(URI(response.location).query).fetch("state")
    end

    def assert_sign_in_refused
      assert_redirected_to new_session_path
      assert_equal "Sorry, we couldn't sign you in with Google.", flash[:alert]
      assert_nil cookies[:session_id].presence
    end
end
