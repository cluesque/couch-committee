require "application_system_test_case"

class TagsTest < ApplicationSystemTestCase
  test "tagging an entry, filtering by the tag, and recoloring it" do
    pat = create(:user)
    list = create(:list, members: [ pat ], name: "Movie night")
    arrival = list.add(create(:movie, name: "Arrival"))
    list.add(create(:movie, name: "Saw It"))
    sign_in_as pat

    visit list_list_entry_path(list, arrival)
    click_on "Add tags"
    within "turbo-frame#tags" do
      fill_in "New tag (optional)", with: "Alice+"
      find("label", text: "Purple").click
      click_on "Save"
    end
    assert_text "Saved."
    assert_selector ".entry-tags .tag-purple", text: "Alice+"

    click_on "Movie night"
    within("li", text: "Arrival") { assert_selector ".tag", text: "Alice+" }
    click_on "Showing: Movies and series"
    within(".dropdown-menu") { click_on "Alice+" }
    assert_link "Arrival"
    assert_no_link "Saw It"

    click_link "Edit", class: "btn"
    within(".list-tags") { click_on "Edit Alice+" }
    within "turbo-frame[id^=tag_]" do
      find("label", text: "Green").click
      click_on "Save"
    end
    assert_text "Saved Alice+."
    assert_selector ".list-tags .tag-green", text: "Alice+"
  end
end
