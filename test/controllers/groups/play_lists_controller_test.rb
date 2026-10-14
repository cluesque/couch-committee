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
