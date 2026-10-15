require "application_system_test_case"

class GroupsTest < ApplicationSystemTestCase
  test "creating a group, adding someone by email, and both seeing it" do
    sign_in_as create(:user, display_name: "Pat", email: "pat@example.com")

    click_on "New group"
    fill_in "Name", with: "The Smiths"
    click_on "Create group"
    assert_text "Created The Smiths."

    fill_in "Add someone by email", with: "sam@example.com"
    click_on "Add"
    assert_text "Added sam@example.com."
    assert_text "Hasn't signed in yet"

    sign_out
    sign_in_with_google(sub: "g-sam", email: "sam@example.com", name: "Sam")

    click_on "The Smiths"
    assert_text "Pat"
    assert_text "Sam"
    assert_no_text "Hasn't signed in yet"
  end

  test "removing a member" do
    pat = create(:user, display_name: "Pat")
    create(:group, name: "The Smiths", members: [ pat, create(:user, display_name: "Sam") ])
    sign_in_as pat

    click_on "The Smiths"
    accept_confirm("Remove Sam from The Smiths?") { click_on "Remove" }

    assert_text "Removed Sam."
    assert_no_button "Remove"
  end
end
