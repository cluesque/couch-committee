require "test_helper"

class Groups::Lists::ListEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @group = create(:group, members: [ @user ])
    @list = create(:list, group: @group, name: "Movie night")
    sign_in_as @user
  end

  test "the list links to adding a title" do
    get group_list_path(@group, @list)

    assert_select "a[href=?]", new_group_list_list_entry_path(@group, @list), text: "Add a title"
  end

  test "searching the catalog by part of a name, ignoring case" do
    create(:season, name: "The Bear", season: 2)
    create(:season, name: "The Bear", season: 1)
    create(:movie, name: "Bear Story")
    create(:movie, name: "Arrival")

    get new_group_list_list_entry_path(@group, @list, q: "bEAr")

    assert_response :success
    assert_equal [ "Bear Story", "The Bear: Season 1", "The Bear: Season 2" ], result_names
  end

  test "nothing is listed until there's a search" do
    create(:movie)

    get new_group_list_list_entry_path(@group, @list)

    assert_select "li", count: 0
  end

  test "SQL wildcards in the search are taken literally" do
    create(:movie, name: "Arrival")

    get new_group_list_list_entry_path(@group, @list, q: "%")

    assert_empty result_names
    assert_select "p", text: /No titles match/
  end

  test "titles already active on the list can't be added again from the results" do
    movie = create(:movie, name: "Arrival")
    @list.add(movie)

    get new_group_list_list_entry_path(@group, @list, q: "Arrival")

    assert_select "li", text: /On this list/
    assert_select "li button", count: 0
  end

  test "adding a title puts it at the end of the list, not yet started" do
    @list.add(create(:movie, name: "First"))
    movie = create(:movie, name: "Arrival")

    assert_difference "@list.list_entries.count", 1 do
      post group_list_list_entries_path(@group, @list), params: { title_id: movie.id }
    end

    assert_redirected_to group_list_path(@group, @list)
    assert_equal "Added Arrival.", flash[:notice]
    follow_redirect!
    assert_equal [ "First", "Arrival" ], css_select("ol > li .fw-medium").map(&:text)
    assert @list.list_entries.find_by!(title: movie).not_started?
  end

  test "adding a title that's already active is refused" do
    movie = create(:movie, name: "Arrival")
    @list.add(movie)

    assert_no_difference "ListEntry.count" do
      post group_list_list_entries_path(@group, @list), params: { title_id: movie.id, q: "Arr" }
    end

    assert_redirected_to new_group_list_list_entry_path(@group, @list, q: "Arr")
    assert_equal "Arrival is already on this list.", flash[:alert]
  end

  test "each list row links to the entry's details" do
    entry = @list.add(create(:movie, name: "Arrival"))

    get group_list_path(@group, @list)

    assert_select "li a[href=?]", group_list_list_entry_path(@group, @list, entry), text: /Arrival/
  end

  test "an entry's details show its progress through the season" do
    season = create(:season, name: "The Bear", season: 3, episode_count: 3)
    entry = @list.add(season)
    WatchRecorder.call(group: @group, episode: season.episodes.first, date: Date.new(2026, 10, 12))

    get group_list_list_entry_path(@group, @list, entry)

    assert_response :success
    assert_select "h1", "The Bear: Season 3"
    assert_select "p", text: /Series · In progress · Last watched Oct 12/
    assert_equal [ "Watched: #{season.episodes.first.label}", "#{season.episodes.second.label} Next", season.episodes.third.label ],
      css_select("ol li .me-auto").map { |item| item.text.gsub("✓", "").squish }
    assert_select "li .badge", text: "Next", count: 1
  end

  test "an entry from another list is not found under this one" do
    other = create(:list, group: @group).add(create(:movie))

    get group_list_list_entry_path(@group, @list, other)

    assert_response :not_found
  end

  test "reordering saves the new order" do
    first, second, third = %w[ First Second Third ].map { |name| @list.add(create(:movie, name: name)) }

    patch reorder_group_list_list_entries_path(@group, @list),
      params: { list_entry_ids: [ third.id, first.id, second.id ] }, as: :json

    assert_response :no_content
    get group_list_path(@group, @list)
    assert_equal [ "Third", "First", "Second" ], css_select("ol > li .fw-medium").map(&:text)
  end

  test "another group's list can't be reordered" do
    others = create(:list)
    a, b = 2.times.map { others.add(create(:movie)) }

    patch reorder_group_list_list_entries_path(others.group, others), params: { list_entry_ids: [ b.id, a.id ] }, as: :json

    assert_response :not_found
    assert_equal [ a, b ], others.list_entries.order(:sequence).to_a
  end

  test "another group's list can't be searched or added to" do
    others = create(:list)

    get new_group_list_list_entry_path(others.group, others)
    assert_response :not_found

    post group_list_list_entries_path(@group, others), params: { title_id: create(:movie).id }
    assert_response :not_found
    assert_empty others.list_entries
  end

  private
    def result_names
      css_select("li .title-name").map(&:text)
    end
end
