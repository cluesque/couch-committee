require "test_helper"

class Groups::ListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @group = create(:group, members: [ @user ])
    sign_in_as @user
  end

  test "the group page lists its lists" do
    create(:list, group: @group, name: "Movie night")
    create(:list, group: @group, name: "Anime")
    create(:list, name: "Someone else's")

    get group_path(@group)

    assert_equal [ "Anime", "Movie night" ], css_select(".list-group a").map { |link| link.text.strip }
    assert_select "a[href=?]", new_group_list_path(@group), text: "New list"
  end

  test "creating a list" do
    get new_group_list_path(@group)
    assert_response :success

    assert_difference "@group.lists.count", 1 do
      post group_lists_path(@group), params: { list: { name: "Movie night", description: "Fridays" } }
    end

    list = @group.lists.sole
    assert_redirected_to group_list_path(@group, list)
    assert_equal [ "Movie night", "Fridays" ], [ list.name, list.description ]
  end

  test "a list needs a name" do
    post group_lists_path(@group), params: { list: { name: "" } }

    assert_response :unprocessable_content
    assert_select ".invalid-feedback", "Name can't be blank"
  end

  test "a list's page shows its name and description" do
    list = create(:list, group: @group, name: "Movie night", description: "Fridays")

    get group_list_path(@group, list)

    assert_response :success
    assert_select "h1", "Movie night"
    assert_select "p", "Fridays"
  end

  test "the default view shows active entries in order with what's next" do
    travel_to Date.new(2026, 10, 14) do
      list = create(:list, group: @group)
      season = create(:season, name: "The Bear", season: 3, episode_count: 0)
      first = create(:episode, title: season, number: 1, name: "Tomorrow", available_on: Date.new(2026, 6, 26))
      create(:episode, title: season, number: 2, name: "Next", available_on: Date.new(2026, 6, 26))
      upcoming = create(:movie, name: "Sequel")
      upcoming.episodes.first.update!(available_on: Date.new(2026, 12, 25))

      entry = list.add(season)
      list.add(upcoming)
      list.add(create(:movie, name: "Done")).update!(state: :watched)
      create(:viewing, list_entry: entry, episode: first, date: Date.new(2026, 10, 12))

      get group_list_path(@group, list)

      rows = css_select("ol > li")
      assert_equal [ "The Bear: Season 3", "Sequel" ], rows.map { |row| row.at_css(".fw-medium").text }
      assert_equal "Next: 2. Next Last watched Oct 12", rows.first.at_css(".small").text.squish
      assert_nil rows.first.at_css(".badge")
      assert_equal "Coming Dec 25", rows[1].at_css(".badge").text.squish
      assert_includes rows[1]["class"], "text-body-secondary"
      assert_equal [ "Series", "Movie" ], rows.map { |row| row.at_css("svg.kind-icon")["aria-label"] }
    end
  end

  test "the list can show just its movies, or just its series" do
    list = create(:list, group: @group, name: "Movie night")
    list.add(create(:movie, name: "Arrival"))
    list.add(create(:season, name: "The Bear"))
    list.add(create(:movie, name: "Heat"))

    get group_list_path(@group, list)
    assert_equal [ "Arrival", "The Bear", "Heat" ], css_select("ol > li .fw-medium").map(&:text)
    assert_select ".dropdown-toggle", text: /Showing: Movies and series/
    assert_equal [ "Movies and series 3", "Movies 2", "Series 1" ], css_select("main .dropdown-item").map { |item| item.text.squish }
    assert_select ".dropdown-item.active[href=?]", group_list_path(@group, list)

    get group_list_path(@group, list, kind: "movie")
    assert_equal [ "Arrival", "Heat" ], css_select("ol > li .fw-medium").map(&:text)
    assert_select ".dropdown-toggle", text: /Showing: Movies/
    assert_select ".dropdown-item.active[href=?]", group_list_path(@group, list, kind: "movie")

    get group_list_path(@group, list, kind: "series")
    assert_equal [ "The Bear" ], css_select("ol > li .fw-medium").map(&:text)
  end

  test "a filter with nothing in it says so" do
    list = create(:list, group: @group)
    list.add(create(:movie))

    get group_list_path(@group, list, kind: "series")

    assert_select "p", "No series on this list right now."
  end

  test "an unknown filter shows everything" do
    list = create(:list, group: @group)
    list.add(create(:movie))
    list.add(create(:season))

    get group_list_path(@group, list, kind: "opera")

    assert_select "ol > li", count: 2
  end

  test "an empty list has no filter" do
    get group_list_path(@group, create(:list, group: @group))

    assert_select ".dropdown-toggle", count: 0
  end

  test "editing a list" do
    list = create(:list, group: @group, name: "Movie night")

    get edit_group_list_path(@group, list)
    assert_response :success

    patch group_list_path(@group, list), params: { list: { name: "Film club", description: "" } }

    assert_redirected_to group_list_path(@group, list)
    assert_equal "Film club", list.reload.name
  end

  test "editing keeps the name required" do
    list = create(:list, group: @group)

    patch group_list_path(@group, list), params: { list: { name: "" } }

    assert_response :unprocessable_content
  end

  test "another group's lists are not found, even under my group's URL" do
    others = create(:list)

    get group_list_path(others.group, others)
    assert_response :not_found

    get group_list_path(@group, others)
    assert_response :not_found

    patch group_list_path(@group, others), params: { list: { name: "Mine now" } }
    assert_response :not_found
  end
end
