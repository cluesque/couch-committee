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

  test "history lists each viewing and each cancellation, newest first" do
    season = create(:season, name: "The Bear", season: 3, episode_count: 0)
    tomorrow = create(:episode, title: season, number: 1, name: "Tomorrow")
    next_episode = create(:episode, title: season, number: 2, name: "Next")
    create(:episode, title: season, number: 3, name: "Doors")
    @play_list.add(season)
    movie = create(:movie, name: "Arrival")
    @play_list.add(movie)
    watch movie.episodes.first, on: Date.new(2026, 9, 20)
    watch tomorrow, on: Date.new(2026, 10, 1)
    travel_to(Time.zone.local(2026, 10, 5, 20)) { @play_list.add(create(:movie, name: "Saw It")).cancel(note: "Too scary.") }
    watch next_episode, on: Date.new(2026, 10, 9)

    get group_play_list_history_path(@group, @play_list)

    assert_response :success
    rows = css_select("ol > li").map do |row|
      [ row.at_css(".fw-medium").text, row.at_css("small").text.squish, row.at_css("div.small")&.text&.squish ]
    end
    assert_equal [
      [ "The Bear: Season 3", "Oct 09", "2. Next" ],
      [ "Saw It", "Oct 05", "Cancelled Too scary." ],
      [ "The Bear: Season 3", "Oct 01", "1. Tomorrow" ],
      [ "Arrival", "Sep 20", nil ]
    ], rows
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
