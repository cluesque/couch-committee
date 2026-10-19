require "application_system_test_case"

class PreviewsTest < ApplicationSystemTestCase
  test "looking a movie over before adding it" do
    pat = create(:user)
    list = create(:list, members: [ pat ], name: "Movie night")
    sign_in_as pat

    visit new_list_list_entry_path(list)
    fill_in "Search movies and shows", with: "arrival"
    click_on "Search"
    fill_in "Why this one? (optional)", with: "Pat loved it"
    click_on "Arrival details", match: :first

    assert_selector "h1", text: "Arrival"
    assert_text "Movie · 2016 · 1h 56m · PG-13"
    assert_field "Why this one? (optional)", with: "Pat loved it"
    click_on "Add to Movie night"

    assert_text "Added Arrival."
    within("ol") { assert_text "“Pat loved it”" }
  end
end
