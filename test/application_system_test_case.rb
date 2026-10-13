require "test_helper"
require "capybara/cuprite"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Chrome's own sandbox can't start inside containers (the dev sandbox, some CI runners).
  driven_by :cuprite, screen_size: [ 390, 844 ], options: { browser_options: { "no-sandbox" => nil } }
end
