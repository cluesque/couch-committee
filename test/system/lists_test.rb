require "application_system_test_case"

# FakeTmdb answers TMDB's side: Arrival, and The Bear with its seasons.
class ListsTest < ApplicationSystemTestCase
  test "building a list from TMDB search and seeing what's next" do
    pat = create(:user)
    create(:group, name: "The Smiths", members: [ pat ])
    sign_in_as pat

    click_on "The Smiths"
    click_on "New list"
    fill_in "Name", with: "Movie night"
    click_on "Create list"
    assert_text "Nothing on this list yet."

    click_on "Add a title"
    fill_in "Search movies and shows", with: "the bear"
    click_on "Search"
    click_on "Seasons of The Bear"
    assert_text "Which season should go on Movie night?"
    click_on "Add The Bear: Season 1"
    assert_text "Added The Bear: Season 1."

    click_on "Add a title"
    fill_in "Search movies and shows", with: "arrival"
    click_on "Search"
    click_on "Add Arrival", match: :first
    assert_text "Added Arrival."

    within "ol" do
      rows = all("li")
      assert_equal [ "The Bear: Season 1", "Arrival" ], rows.map { |row| row.find(".fw-medium").text }
      assert_includes rows[0].text, "Next: 1. System"
    end
  end

  test "a title entered by hand before TMDB can still be added from search" do
    travel_to Date.new(2026, 10, 14)
    pat = create(:user)
    group = create(:group, members: [ pat ])
    list = create(:list, group: group, name: "Movie night")
    movie = create(:movie, name: "Sequel", tmdb_id: nil)
    movie.episodes.first.update!(available_on: Date.new(2026, 12, 25))
    sign_in_as pat

    visit new_group_list_list_entry_path(group, list)
    fill_in "Search movies and shows", with: "sequel"
    click_on "Search"
    assert_text "Entered by hand"
    click_on "Add Sequel"

    within("ol") { assert_text "Coming Dec 25" }
  ensure
    travel_back
  end
end
