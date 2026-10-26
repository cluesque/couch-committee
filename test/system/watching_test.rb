require "application_system_test_case"

class WatchingTest < ApplicationSystemTestCase
  setup do
    @pat = create(:user)
    @movie_night = create(:list, members: [ @pat ], name: "Movie night")
  end

  test "watching a season episode by episode until it's finished" do
    season = create(:season, name: "The Bear", season: 3, episode_count: 0)
    create(:episode, title: season, number: 1, name: "Tomorrow")
    create(:episode, title: season, number: 2, name: "Next")
    entry = @movie_night.add(season)
    detail_path = list_list_entry_path(@movie_night, entry)
    sign_in_as @pat

    visit list_path(@movie_night)
    click_on "The Bear: Season 3"
    assert_current_path detail_path
    click_on "Mark as watched…"

    within "turbo-frame#watch" do
      assert_select "Episode", selected: "1. Tomorrow"
      click_on "Mark watched"
    end
    assert_text "Watched The Bear: Season 3 · 1. Tomorrow."
    assert_current_path list_path(@movie_night)
    assert_text "Next: 2. Next"

    click_on "The Bear: Season 3"
    click_on "Mark as watched…"
    assert_current_path detail_path, ignore_query: true
    within("turbo-frame#watch") { click_on "Mark watched" }

    assert_text "Finished The Bear: Season 3."
    assert_no_text "Next: 2. Next"
    assert_text "All caught up."
  end

  test "watching a movie checks it off on this list only" do
    movie = create(:movie, name: "Arrival")
    anime = create(:list, members: [ @pat ], name: "Anime")
    @movie_night.add(movie)
    anime.add(movie)
    sign_in_as @pat

    visit list_path(@movie_night)
    click_on "Arrival"
    click_on "Mark as watched…"
    within("turbo-frame#watch") { click_on "Mark watched" }

    assert_text "Watched Arrival."
    assert_no_link "Arrival"
    visit list_path(anime)
    assert_link "Arrival"
  end

  # At any hour, one of these is already on a different date than UTC, the server's time zone.
  test "the watch date defaults to today in the browser's time zone, not the server's" do
    entry = @movie_night.add(create(:movie, name: "Arrival"))
    sign_in_as @pat

    %w[ Pacific/Kiritimati Pacific/Pago_Pago ].each do |zone|
      page.driver.browser.page.command("Emulation.setTimezoneOverride", timezoneId: zone)
      visit list_list_entry_path(@movie_night, entry)
      click_on "Mark as watched…"

      within("turbo-frame#watch") { assert_field "Watched on", with: Time.current.in_time_zone(zone).to_date.iso8601 }
    end
  end

  test "the date typed is kept when the form comes back with an error" do
    entry = @movie_night.add(create(:movie, name: "Arrival"))
    sign_in_as @pat

    visit new_list_list_entry_viewing_path(@movie_night, entry)
    page.execute_script("document.querySelector('#viewing_date').removeAttribute('required')")
    fill_in "Watched on", with: ""
    click_on "Mark watched"

    assert_field "Watched on", with: ""
  end
end
