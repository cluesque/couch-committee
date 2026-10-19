require "test_helper"

class WatchingAgainTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @group = create(:group, members: [ @user ])
    @list = create(:list, group: @group)
    @season = create(:season, name: "The Bear", season: 3, episode_count: 2)
    @earlier = @list.add(@season)
    @season.episodes.each { |episode| WatchRecorder.call(@earlier, episode: episode, date: Date.new(2026, 10, 1)) }
    sign_in_as @user
  end

  test "a finished entry offers to watch it again" do
    get group_list_list_entry_path(@group, @list, @earlier)

    assert_select "form[action=?] input[name=title_id][value=?]", group_list_list_entries_path(@group, @list), @season.id.to_s
    assert_select "button", "Add to list again"
    assert_select "turbo-frame#watch", count: 0
  end

  test "watching again adds a fresh entry and leaves the earlier one exactly as it was" do
    earlier_viewings = @earlier.viewings.map(&:attributes)

    assert_difference "ListEntry.count", 1 do
      post group_list_list_entries_path(@group, @list), params: { title_id: @season.id }
    end

    assert_equal "Added The Bear: Season 3 again.", flash[:notice]
    rewatch = @list.list_entries.active.sole
    assert rewatch.not_started?
    assert_equal @season.episodes.first, rewatch.next_episode
    assert_nil rewatch.last_viewed_on

    @earlier.reload
    assert @earlier.watched?
    assert_equal earlier_viewings, @earlier.viewings.map(&:attributes)
  end

  test "watching the rewatch records against it alone" do
    post group_list_list_entries_path(@group, @list), params: { title_id: @season.id }
    rewatch = @list.list_entries.active.sole

    WatchRecorder.call(rewatch, episode: @season.episodes.first, date: Date.new(2026, 10, 15))

    assert rewatch.reload.in_progress?
    assert_equal 2, @earlier.viewings.count
    assert_equal [ Date.new(2026, 10, 15) ], rewatch.viewings.map(&:date)
  end

  test "once it's back on the list, the earlier entry points to the new one" do
    rewatch = @list.add(@season)

    get group_list_list_entry_path(@group, @list, @earlier)

    assert_select "button", text: "Add to list again", count: 0
    assert_select "a[href=?]", group_list_list_entry_path(@group, @list, rewatch)
  end

  test "a cancelled title can be put back too" do
    movie = create(:movie, name: "Saw It")
    @list.add(movie).cancel(note: "Not tonight.")

    post group_list_list_entries_path(@group, @list), params: { title_id: movie.id }

    assert_equal "Added Saw It again.", flash[:notice]
    assert @list.list_entries.active.exists?(title: movie)
  end

  test "a finished title can also be re-added from search" do
    get new_group_list_list_entry_path(@group, @list, q: "Bear")

    assert_select "li button", text: "Add"
  end
end
