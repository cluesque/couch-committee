require "test_helper"

class Groups::PlayLists::HistoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @group = create(:group, members: [ @user ])
    @play_list = create(:play_list, group: @group)
    sign_in_as @user
  end

  test "the playlist links to its history" do
    get group_play_list_path(@group, @play_list)

    assert_select "a[href=?]", group_play_list_history_path(@group, @play_list), text: "History"
  end

  test "history shows what was watched and when, and what was cancelled and why, newest first" do
    season = create(:season, name: "The Bear", season: 3, episode_count: 2)
    @play_list.add(season)
    watch season.episodes.first, on: Date.new(2026, 10, 1)
    watch season.episodes.second, on: Date.new(2026, 10, 9)
    movie = create(:movie, name: "Arrival")
    @play_list.add(movie)
    watch movie.episodes.first, on: Date.new(2026, 9, 20)
    travel_to(Time.zone.local(2026, 10, 12, 20)) { @play_list.add(create(:movie, name: "Saw It")).cancel(note: "Too scary.") }
    @play_list.add(create(:movie, name: "Still to watch"))

    get group_play_list_history_path(@group, @play_list)

    assert_response :success
    rows = css_select("ol > li")
    assert_equal [ "Saw It", "The Bear: Season 3", "Arrival" ], rows.map { |row| row.at_css(".fw-medium").text }
    assert_equal [ "Cancelled", "Watched", "Watched" ], rows.map { |row| row.at_css(".badge").text }
    assert_equal [ "Oct 12 · Too scary.", "Oct 01 – Oct 09", "Sep 20" ], rows.map { |row| row.at_css(".small").text.squish }
  end

  test "an empty history says so" do
    get group_play_list_history_path(@group, @play_list)

    assert_select "p", "Nothing watched or cancelled yet."
  end

  test "another group's history is not found" do
    others = create(:play_list)

    get group_play_list_history_path(others.group, others)

    assert_response :not_found
  end

  private
    def watch(episode, on:)
      WatchRecorder.call(group: @group, episode: episode, date: on)
    end
end
