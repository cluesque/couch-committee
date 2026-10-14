require "test_helper"

class Groups::PlayListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @group = create(:group, members: [ @user ])
    sign_in_as @user
  end

  test "the group page lists its playlists" do
    create(:play_list, group: @group, name: "Movie night")
    create(:play_list, group: @group, name: "Anime")
    create(:play_list, name: "Someone else's")

    get group_path(@group)

    assert_equal [ "Anime", "Movie night" ], css_select(".list-group a").map { |link| link.text.strip }
    assert_select "a[href=?]", new_group_play_list_path(@group), text: "New playlist"
  end

  test "creating a playlist" do
    get new_group_play_list_path(@group)
    assert_response :success

    assert_difference "@group.play_lists.count", 1 do
      post group_play_lists_path(@group), params: { play_list: { name: "Movie night", description: "Fridays" } }
    end

    play_list = @group.play_lists.sole
    assert_redirected_to group_play_list_path(@group, play_list)
    assert_equal [ "Movie night", "Fridays" ], [ play_list.name, play_list.description ]
  end

  test "a playlist needs a name" do
    post group_play_lists_path(@group), params: { play_list: { name: "" } }

    assert_response :unprocessable_content
    assert_select ".invalid-feedback", "Name can't be blank"
  end

  test "a playlist's page shows its name and description" do
    play_list = create(:play_list, group: @group, name: "Movie night", description: "Fridays")

    get group_play_list_path(@group, play_list)

    assert_response :success
    assert_select "h1", "Movie night"
    assert_select "p", "Fridays"
  end

  test "the default view shows active entries in order with what's next" do
    travel_to Date.new(2026, 10, 14) do
      play_list = create(:play_list, group: @group)
      season = create(:season, name: "The Bear", season: 3, episode_count: 0)
      first = create(:episode, title: season, number: 1, name: "Tomorrow", available_on: Date.new(2026, 6, 26))
      create(:episode, title: season, number: 2, name: "Next", available_on: Date.new(2026, 6, 26))
      upcoming = create(:movie, name: "Sequel")
      upcoming.episodes.first.update!(available_on: Date.new(2026, 12, 25))

      entry = play_list.add(season)
      play_list.add(upcoming)
      play_list.add(create(:movie, name: "Done")).update!(state: :watched)
      create(:viewing, list_entry: entry, episode: first, date: Date.new(2026, 10, 12))

      get group_play_list_path(@group, play_list)

      rows = css_select("ol > li")
      assert_equal [ "The Bear: Season 3", "Sequel" ], rows.map { |row| row.at_css(".fw-medium").text }
      assert_equal "Next: 2. Next Last watched Oct 12", rows.first.at_css(".small").text.squish
      assert_nil rows.first.at_css(".badge")
      assert_equal "Coming Dec 25", rows[1].at_css(".badge").text.squish
      assert_includes rows[1]["class"], "bg-body-tertiary"
    end
  end

  test "editing a playlist" do
    play_list = create(:play_list, group: @group, name: "Movie night")

    get edit_group_play_list_path(@group, play_list)
    assert_response :success

    patch group_play_list_path(@group, play_list), params: { play_list: { name: "Film club", description: "" } }

    assert_redirected_to group_play_list_path(@group, play_list)
    assert_equal "Film club", play_list.reload.name
  end

  test "editing keeps the name required" do
    play_list = create(:play_list, group: @group)

    patch group_play_list_path(@group, play_list), params: { play_list: { name: "" } }

    assert_response :unprocessable_content
  end

  test "another group's playlists are not found, even under my group's URL" do
    others = create(:play_list)

    get group_play_list_path(others.group, others)
    assert_response :not_found

    get group_play_list_path(@group, others)
    assert_response :not_found

    patch group_play_list_path(@group, others), params: { play_list: { name: "Mine now" } }
    assert_response :not_found
  end
end
