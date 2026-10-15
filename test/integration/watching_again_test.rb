require "test_helper"

class WatchingAgainTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @group = create(:group, members: [ @user ])
    @play_list = create(:play_list, group: @group)
    @season = create(:season, name: "The Bear", season: 3, episode_count: 2)
    @earlier = @play_list.add(@season)
    @season.episodes.each { |episode| WatchRecorder.call(group: @group, episode: episode, date: Date.new(2026, 10, 1)) }
    sign_in_as @user
  end

  test "a finished entry offers to watch it again" do
    get group_play_list_list_entry_path(@group, @play_list, @earlier)

    assert_select "form[action=?] input[name=title_id][value=?]", group_play_list_list_entries_path(@group, @play_list), @season.id.to_s
    assert_select "button", "Watch again"
    assert_select "turbo-frame#watch", count: 0
  end

  test "watching again adds a fresh entry and leaves the earlier one exactly as it was" do
    earlier_viewings = @earlier.viewings.map(&:attributes)

    assert_difference "ListEntry.count", 1 do
      post group_play_list_list_entries_path(@group, @play_list), params: { title_id: @season.id }
    end

    assert_equal "Added The Bear: Season 3 again.", flash[:notice]
    rewatch = @play_list.list_entries.active.sole
    assert rewatch.not_started?
    assert_equal @season.episodes.first, rewatch.next_episode
    assert_nil rewatch.last_viewed_on

    @earlier.reload
    assert @earlier.watched?
    assert_equal earlier_viewings, @earlier.viewings.map(&:attributes)
  end

  test "watching the rewatch records against it alone" do
    post group_play_list_list_entries_path(@group, @play_list), params: { title_id: @season.id }
    rewatch = @play_list.list_entries.active.sole

    WatchRecorder.call(group: @group, episode: @season.episodes.first, date: Date.new(2026, 10, 15))

    assert rewatch.reload.in_progress?
    assert_equal 2, @earlier.viewings.count
    assert_equal [ Date.new(2026, 10, 15) ], rewatch.viewings.map(&:date)
  end

  test "once it's back on the playlist, the earlier entry points to the new one" do
    rewatch = @play_list.add(@season)

    get group_play_list_list_entry_path(@group, @play_list, @earlier)

    assert_select "button", text: "Watch again", count: 0
    assert_select "a[href=?]", group_play_list_list_entry_path(@group, @play_list, rewatch)
  end

  test "a cancelled title can be put back too" do
    movie = create(:movie, name: "Saw It")
    @play_list.add(movie).cancel(note: "Not tonight.")

    post group_play_list_list_entries_path(@group, @play_list), params: { title_id: movie.id }

    assert_equal "Added Saw It again.", flash[:notice]
    assert @play_list.list_entries.active.exists?(title: movie)
  end

  test "a finished title can also be re-added from search" do
    get new_group_play_list_list_entry_path(@group, @play_list, q: "Bear")

    assert_select "li button", text: "Add"
  end
end
