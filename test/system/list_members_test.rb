require "application_system_test_case"

class ListMembersTest < ApplicationSystemTestCase
  test "sharing a list by email, and both seeing it" do
    sign_in_as create(:user, display_name: "Pat", email: "pat@example.com")

    click_on "New list"
    fill_in "Name", with: "Movie night"
    click_on "Create list"
    assert_text "Created Movie night."

    click_link "Edit", class: "btn"
    fill_in "Add someone by email", with: "sam@example.com"
    click_on "Add"
    assert_text "Added sam@example.com."
    assert_text "Hasn't signed in yet"

    sign_out
    sign_in_with_google(sub: "g-sam", email: "sam@example.com", name: "Sam")
    assert_selector "h1", text: "Welcome, Sam!"
    click_on "Get started"
    assert_selector "h1", text: "Just Me"
    click_on "Home"

    assert_link "Movie night", text: /with Pat/
    click_on "Movie night"
    click_link "Edit", class: "btn"
    assert_text "Pat"
    assert_text "Sam"
    assert_no_text "Hasn't signed in yet"
  end

  test "removing someone" do
    pat = create(:user, display_name: "Pat")
    list = create(:list, name: "Movie night", members: [ pat, create(:user, display_name: "Sam") ])
    sign_in_as pat

    visit edit_list_path(list)
    accept_confirm("Remove Sam from Movie night?") { click_on "Remove" }

    assert_text "Removed Sam from Movie night."
    assert_no_button "Remove"
  end

  test "deleting a list, then undoing it" do
    pat = create(:user, display_name: "Pat")
    list = create(:list, name: "Movie night", members: [ pat, create(:user, display_name: "Sam") ])
    sign_in_as pat

    visit edit_list_path(list)
    accept_confirm("Delete Movie night for you, Sam?") { click_on "Delete list" }

    assert_text "Deleted Movie night."
    assert_no_link "Movie night"
    click_on "Undo"

    assert_text "Restored Movie night."
    assert_selector "h1", text: "Movie night"
  end
end
