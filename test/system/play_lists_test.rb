require "application_system_test_case"

class PlayListsTest < ApplicationSystemTestCase
  test "building a playlist and seeing what's next" do
    travel_to Date.new(2026, 10, 14)

    pat = create(:user)
    create(:group, name: "The Smiths", members: [ pat ])
    season = create(:season, name: "The Bear", season: 3, episode_count: 0)
    create(:episode, title: season, number: 1, name: "Tomorrow", available_on: Date.new(2026, 6, 26))
    create(:episode, title: season, number: 2, name: "Next", available_on: Date.new(2026, 6, 26))
    movie = create(:movie, name: "Sequel")
    movie.episodes.first.update!(available_on: Date.new(2026, 12, 25))
    sign_in_as pat

    click_on "The Smiths"
    click_on "New playlist"
    fill_in "Name", with: "Movie night"
    click_on "Create playlist"
    assert_text "Nothing on this playlist yet."

    click_on "Add a title"
    fill_in "Search titles", with: "bear"
    click_on "Search"
    click_on "Add The Bear: Season 3"
    assert_text "Added The Bear: Season 3."

    click_on "Add a title"
    fill_in "Search titles", with: "sequel"
    click_on "Search"
    click_on "Add Sequel"

    within "ol" do
      rows = all("li")
      assert_equal [ "The Bear: Season 3", "Sequel" ], rows.map { |row| row.find(".fw-medium").text }
      assert_includes rows[0].text, "Next: 1. Tomorrow"
      assert_includes rows[1].text, "Coming Dec 25"
    end
  ensure
    travel_back
  end
end
