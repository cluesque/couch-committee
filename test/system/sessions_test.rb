require "application_system_test_case"

class SessionsTest < ApplicationSystemTestCase
  test "signing in with Google and signing out" do
    visit root_path
    assert_button "Sign in with Google"

    sign_in_with_google(sub: "g-1", email: "pat@example.com", name: "Pat")

    assert_text "Pat"
    assert_current_path root_path

    click_on "Sign out"

    assert_text "You've been signed out."
    assert_button "Sign in with Google"

    visit root_path
    assert_current_path new_session_path
  end
end
