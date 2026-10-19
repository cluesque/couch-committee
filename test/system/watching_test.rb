require "application_system_test_case"

class WatchingTest < ApplicationSystemTestCase
  setup do
    @pat = create(:user)
    @group = create(:group, members: [ @pat ])
    @movie_night = create(:list, group: @group, name: "Movie night")
  end

  test "watching a season episode by episode until it's finished" do
    season = create(:season, name: "The Bear", season: 3, episode_count: 0)
    create(:episode, title: season, number: 1, name: "Tomorrow")
    create(:episode, title: season, number: 2, name: "Next")
    entry = @movie_night.add(season)
    detail_path = group_list_list_entry_path(@group, @movie_night, entry)
    sign_in_as @pat

    visit group_list_path(@group, @movie_night)
    click_on "The Bear: Season 3"
    assert_current_path detail_path
    click_on "Mark as watched…"

    within "turbo-frame#watch" do
      assert_select "Episode", selected: "1. Tomorrow"
      click_on "Mark watched"
    end
    assert_text "Watched The Bear: Season 3 · 1. Tomorrow."
    assert_current_path group_list_path(@group, @movie_night)
    assert_text "Next: 2. Next"

    click_on "The Bear: Season 3"
    click_on "Mark as watched…"
    assert_current_path detail_path, ignore_query: true
    within("turbo-frame#watch") { click_on "Mark watched" }

    assert_text "Finished The Bear: Season 3."
    assert_no_text "Next: 2. Next"
    assert_text "Nothing on this list yet."
  end

  test "watching a movie checks it off on this list only" do
    movie = create(:movie, name: "Arrival")
    anime = create(:list, group: @group, name: "Anime")
    @movie_night.add(movie)
    anime.add(movie)
    sign_in_as @pat

    visit group_list_path(@group, @movie_night)
    click_on "Arrival"
    click_on "Mark as watched…"
    within("turbo-frame#watch") { click_on "Mark watched" }

    assert_text "Watched Arrival."
    assert_no_link "Arrival"
    visit group_list_path(@group, anime)
    assert_link "Arrival"
  end
end
