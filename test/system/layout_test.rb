require "application_system_test_case"

class LayoutTest < ApplicationSystemTestCase
  test "signed-in pages render with Turbo loaded" do
    sign_in_as create(:user)

    visit root_path

    assert_selector ".navbar-brand", text: "Couch Committee"
    assert_equal "object", evaluate_script("typeof window.Turbo")
  end
end
