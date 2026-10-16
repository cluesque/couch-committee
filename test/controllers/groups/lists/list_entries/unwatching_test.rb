require "test_helper"

class Groups::Lists::ListEntries::UnwatchingTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @group = create(:group, members: [ @user ])
    @list = create(:list, group: @group, name: "Movie night")
    @anime = create(:list, group: @group, name: "Anime")
    @movie = create(:movie, name: "Arrival")
    @entry = @list.add(@movie)
    @anime.add(@movie)
    WatchRecorder.call(group: @group, episode: @movie.episodes.first, date: Date.new(2026, 10, 1))
    @viewing = @entry.viewings.sole
    sign_in_as @user
  end

  test "history offers to unwatch each viewing, warning which other lists it's on" do
    get group_list_history_path(@group, @list)

    assert_select "form[action=?][data-turbo-confirm=?] button", group_list_list_entry_viewing_path(@group, @list, @entry, @viewing),
      "Unwatch Arrival (Oct 01)? It's also recorded on Anime, and will be removed there too.", text: "Unwatch"
  end

  test "unwatching removes the watch everywhere and returns to history" do
    delete group_list_list_entry_viewing_path(@group, @list, @entry, @viewing)

    assert_redirected_to group_list_history_path(@group, @list)
    assert_equal "Unwatched Arrival. Also removed from Anime.", flash[:notice]
    assert_equal 0, Viewing.count
    assert @entry.reload.not_started?
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
    WatchRecorder.call(group: others.group, episode: entry.title.episodes.first, date: Date.new(2026, 10, 1))
    viewing = entry.viewings.sole

    delete group_list_list_entry_viewing_path(others.group, others, entry, viewing)

    assert_response :not_found
    assert Viewing.exists?(viewing.id)
  end
end
