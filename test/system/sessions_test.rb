require "application_system_test_case"

class SessionsTest < ApplicationSystemTestCase
  test "signing in with Google and signing out" do
    visit root_path
    assert_button "Sign in with Google"

    sign_in_with_google(sub: "g-1", email: "pat@example.com", name: "Pat")

    assert_current_path welcome_path
    assert_button "Account menu", text: "P"
    within("nav") { assert_no_text "pat@example.com" }

    click_on "Account menu"
    within(".dropdown-menu") do
      assert_text "Pat"
      assert_text "pat@example.com"
      click_on "Sign out"
    end

    assert_text "You've been signed out."
    assert_button "Sign in with Google"

    visit root_path
    assert_current_path new_session_path
  end

  test "dev sign-in as any email" do
    visit new_session_path
    fill_in "Email", with: "sam@example.com"
    fill_in "Name (for someone new)", with: "Sam"
    click_on "Dev sign-in"

    assert_current_path welcome_path
    assert_button "Account menu", text: "S"
  end
end
