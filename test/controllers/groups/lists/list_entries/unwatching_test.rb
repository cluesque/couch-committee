require "test_helper"

class Groups::Lists::ListEntries::UnwatchingTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @group = create(:group, members: [ @user ])
    @list = create(:list, group: @group, name: "Movie night")
    @movie = create(:movie, name: "Arrival")
    @entry = @list.add(@movie)
    @viewing = WatchRecorder.call(@entry, episode: @movie.episodes.first, date: Date.new(2026, 10, 1))
    sign_in_as @user
  end

  test "history offers to unwatch each viewing" do
    get group_list_history_path(@group, @list)

    assert_select "form[action=?][data-turbo-confirm=?] button", group_list_list_entry_viewing_path(@group, @list, @entry, @viewing),
      "Unwatch Arrival (Oct 01)?", text: "Unwatch"
  end

  test "unwatching removes the watch from this list only and returns to history" do
    elsewhere = create(:list, group: @group).add(@movie)
    WatchRecorder.call(elsewhere, episode: @movie.episodes.first, date: Date.new(2026, 10, 1))

    delete group_list_list_entry_viewing_path(@group, @list, @entry, @viewing)

    assert_redirected_to group_list_history_path(@group, @list)
    assert_equal "Unwatched Arrival.", flash[:notice]
    assert_not Viewing.exists?(@viewing.id)
    assert @entry.reload.not_started?
    assert elsewhere.reload.watched?
  end

  test "a refused unwatch explains why" do
    @list.add(@movie)

    delete group_list_list_entry_viewing_path(@group, @list, @entry, @viewing)

    assert_redirected_to group_list_history_path(@group, @list)
    assert_match(/already back on Movie night for a rewatch/, flash[:alert])
    assert Viewing.exists?(@viewing.id)
  end

  test "another group's viewings can't be unwatched" do
    others = create(:list)
    entry = others.add(create(:movie))
    viewing = WatchRecorder.call(entry, episode: entry.title.episodes.first, date: Date.new(2026, 10, 1))

    delete group_list_list_entry_viewing_path(others.group, others, entry, viewing)

    assert_response :not_found
    assert Viewing.exists?(viewing.id)
  end
end
