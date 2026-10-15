require "application_system_test_case"

class LayoutTest < ApplicationSystemTestCase
  test "signed-in pages render with Turbo loaded" do
    sign_in_as create(:user)

    visit root_path

    assert_selector ".navbar-brand", text: "Couch Committee"
    assert_equal "object", evaluate_script("typeof window.Turbo")
  end

  test "a flash message isn't replayed when going back to the page" do
    sign_in_as create(:user)

    click_on "New group"
    fill_in "Name", with: "The Smiths"
    click_on "Create group"
    assert_text "Created The Smiths."

    click_on "New playlist"
    go_back

    assert_selector "h1", text: "The Smiths"
    assert_no_text "Created The Smiths."
  end
end
