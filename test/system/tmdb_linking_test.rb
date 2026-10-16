require "application_system_test_case"

class TmdbLinkingTest < ApplicationSystemTestCase
  test "linking a hand-entered season to TMDB keeps what's been watched" do
    pat = create(:user)
    group = create(:group, members: [ pat ])
    list = create(:list, group: group, name: "Movie night")
    season = create(:season, name: "Bear", season: 1, episode_count: 0, tmdb_id: nil)
    first = create(:episode, title: season, number: 1, name: "Pilot")
    create(:episode, title: season, number: 2, name: "Second")
    entry = list.add(season)
    WatchRecorder.call(group: group, episode: first, date: Date.new(2026, 10, 1))
    sign_in_as pat

    visit group_list_list_entry_path(group, list, entry)
    click_on "Find on TMDB"
    assert_field "Search TMDB", with: "Bear"
    fill_in "Search TMDB", with: "the bear"
    click_on "Search"
    click_on "Link to The Bear"

    assert_text "Linked The Bear: Season 1 to TMDB."
    assert_current_path group_list_list_entry_path(group, list, entry)
    assert_selector "h1", text: "The Bear: Season 1"
    assert_text "Series · 2022 · TV-MA · Hulu"
    within("ol li:first-child") do
      assert_text "Watched:"
      assert_text "1. System"
    end
    assert_selector "ol li", count: 8

    click_on "Refresh"
    assert_text "Refreshed The Bear: Season 1 from TMDB."
    assert_current_path group_list_list_entry_path(group, list, entry)
  end
end
