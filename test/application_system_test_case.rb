require "test_helper"
require "capybara/cuprite"

Capybara.enable_aria_label = true

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Chrome's own sandbox can't start inside containers (the dev sandbox, some CI runners).
  driven_by :cuprite, screen_size: [ 390, 844 ], options: { browser_options: { "no-sandbox" => nil } }

  setup do
    @google_authorize_url = GoogleSignIn.authorize_url
    GoogleSignIn.authorize_url = "#{page.server.base_url}/fake_google/authorize"
  end

  teardown do
    GoogleSignIn.authorize_url = @google_authorize_url
  end

  def sign_in_with_google(**claims)
    FakeGoogle.next_authorization_code = FakeGoogle.authorization_code_for(**claims)
    visit new_session_path
    click_on "Sign in with Google"
  end

  def sign_in_as(user)
    sign_in_with_google(sub: user.google_id, email: user.email, name: user.display_name)
    assert_button "Sign out"
  end
end

# Has to follow the class above: loading ActionDispatch::SystemTestCase sets Capybara.app itself.
Capybara.app = Rack::Builder.app do
  map("/fake_google/authorize") { run FakeGoogle::ConsentScreen }
  run Rails.application
end
