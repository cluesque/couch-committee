require "application_system_test_case"

class UnwatchingTest < ApplicationSystemTestCase
  test "unwatching an episode from history puts it back" do
    pat = create(:user)
    list = create(:list, members: [ pat ], name: "Movie night")
    season = create(:season, name: "The Bear", season: 1, episode_count: 0)
    first = create(:episode, title: season, number: 1, name: "System")
    create(:episode, title: season, number: 2, name: "Hands")
    WatchRecorder.call(list.add(season), episode: first, date: Date.new(2026, 10, 1))
    sign_in_as pat

    visit list_history_path(list)
    accept_confirm("Unwatch The Bear · 1. System (Oct 01)?") { click_on "Unwatch" }

    assert_text "Unwatched The Bear · 1. System."
    assert_text "Nothing watched or removed yet."
    visit list_path(list)
    assert_text "Next: 1. System"
  end
end
