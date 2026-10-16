require "test_helper"

class Groups::Lists::ListEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @group = create(:group, members: [ @user ])
    @list = create(:list, group: @group, name: "Movie night")
    sign_in_as @user
  end

  teardown do
    FakeTmdb.unreachable = false
  end

  test "the list links to adding a title" do
    get group_list_path(@group, @list)

    assert_select "a[href=?]", new_group_list_list_entry_path(@group, @list), text: "Add a title"
  end

  test "searching finds movies on TMDB, each with an Add button" do
    get new_group_list_list_entry_path(@group, @list, q: "arrival")

    assert_response :success
    assert_equal "Arrival", result_names.first
    assert_select "ul:first-of-type li:first-child", text: /2016/
    assert_select "form#add_title[action=?]", group_list_list_entries_path(@group, @list)
    assert_select "button[form=add_title][name=tmdb_movie_id][value='329865']", "Add"
  end

  test "a show leads to its seasons rather than an Add button" do
    get new_group_list_list_entry_path(@group, @list, q: "the bear")

    assert_equal "The Bear", result_names.first
    assert_select "button[form=add_title][name=tmdb_show_id][value='136315'][formaction=?]",
      seasons_group_list_list_entries_path(@group, @list), text: "Seasons ›"
    assert_not_includes result_names, "Bart the Bear"
  end

  test "nothing is listed until there's a search" do
    get new_group_list_list_entry_path(@group, @list)

    assert_select "li", count: 0
  end

  test "a search nothing matches says so" do
    get new_group_list_list_entry_path(@group, @list, q: "no such title anywhere")

    assert_select "p", text: /No movies or shows match/
  end

  test "titles entered by hand before TMDB still turn up, until they're linked" do
    hand_entered = create(:season, name: "The Bear", season: 2, tmdb_id: nil)
    create(:season, name: "The Bear", season: 1, tmdb_id: 136315)

    get new_group_list_list_entry_path(@group, @list, q: "bear")

    assert_select "h2", "Entered by hand"
    assert_select "button[form=add_title][name=title_id][value=?]", hand_entered.id.to_s
    assert_select "button[name=title_id]", count: 1
  end

  test "SQL wildcards in the search are taken literally" do
    create(:movie, name: "Arrival", tmdb_id: nil)

    get new_group_list_list_entry_path(@group, @list, q: "%")

    assert_select "h2", text: "Entered by hand", count: 0
  end

  test "a movie already active on the list says so instead of offering Add" do
    @list.add(import_movie)

    get new_group_list_list_entry_path(@group, @list, q: "arrival")

    assert_select "ul:first-of-type li:first-child", text: /On this list/
    assert_select "ul:first-of-type li:first-child button", count: 0
  end

  test "when TMDB can't be reached, the search says so" do
    FakeTmdb.unreachable = true

    get new_group_list_list_entry_path(@group, @list, q: "arrival")

    assert_response :success
    assert_select ".alert-danger", "Couldn't reach TMDB just now. Please try again."
    assert_select "p", text: /No movies or shows match/, count: 0
  end

  test "a show's seasons each have an Add button, without specials" do
    get seasons_group_list_list_entries_path(@group, @list, tmdb_show_id: 136315, q: "the bear")

    assert_response :success
    assert_select "h1", "The Bear"
    assert_equal [ "Season 1", "Season 2", "Season 3", "Season 4", "Season 5" ], css_select(".title-name").map(&:text)
    assert_select "li:first-child", text: /2022 · 8 episodes/
    assert_select "form#add_title input[name=tmdb_show_id][value='136315']"
    assert_select "button[form=add_title][name=season][value='1']"
    assert_select "a[href=?]", new_group_list_list_entry_path(@group, @list, q: "the bear"), text: "← Search results"
  end

  test "a season already active on the list says so" do
    @list.add(Tmdb::Importer.new(client: Tmdb::Client.new(token: "test")).import_season(136315, 1))

    get seasons_group_list_list_entries_path(@group, @list, tmdb_show_id: 136315)

    assert_select "li:first-child", text: /On this list/
    assert_select "li:first-child button", count: 0
  end

  test "when TMDB can't be reached, the seasons page sends you back to search" do
    FakeTmdb.unreachable = true

    get seasons_group_list_list_entries_path(@group, @list, tmdb_show_id: 136315, q: "the bear")

    assert_redirected_to new_group_list_list_entry_path(@group, @list, q: "the bear")
    assert_equal "Couldn't reach TMDB just now. Please try again.", flash[:alert]
  end

  test "adding a TMDB movie imports it and puts it at the end of the list, not yet started" do
    @list.add(create(:movie, name: "First"))

    assert_difference [ "Title.count", "@list.list_entries.count" ], 1 do
      post group_list_list_entries_path(@group, @list), params: { tmdb_movie_id: 329865, q: "arrival" }
    end

    assert_redirected_to group_list_path(@group, @list)
    assert_equal "Added Arrival.", flash[:notice]
    follow_redirect!
    assert_equal [ "First", "Arrival" ], css_select("ol > li .fw-medium").map(&:text)
    assert @list.list_entries.find_by!(title: Title.find_by!(tmdb_id: 329865)).not_started?
  end

  test "adding a movie that's already in the catalog reuses it" do
    import_movie

    assert_no_difference "Title.count" do
      post group_list_list_entries_path(@group, @list), params: { tmdb_movie_id: 329865 }
    end
    assert_equal "Added Arrival.", flash[:notice]
  end

  test "adding a season imports it with its episodes" do
    post group_list_list_entries_path(@group, @list), params: { tmdb_show_id: 136315, season: 1, q: "the bear" }

    assert_equal "Added The Bear: Season 1.", flash[:notice]
    season = @list.list_entries.sole.title
    assert_equal [ 136315, 1, 8 ], [ season.tmdb_id, season.season, season.episodes.count ]
  end

  test "the search results offer an optional recommendation that Enter can't submit by accident" do
    get new_group_list_list_entry_path(@group, @list, q: "arrival", recommendation: "Kept from before")

    assert_select "form#add_title input[name=recommendation][value=?]", "Kept from before"
    assert_select "form#add_title > button[type=submit][disabled]:first-child"
  end

  test "adding a movie with a recommendation" do
    post group_list_list_entries_path(@group, @list), params: { tmdb_movie_id: 329865, recommendation: "Pat loved it" }

    assert_equal "Pat loved it", @list.list_entries.sole.recommendation
  end

  test "a recommendation typed before choosing a show's seasons comes along" do
    post seasons_group_list_list_entries_path(@group, @list), params: { tmdb_show_id: 136315, q: "the bear", recommendation: "So good" }

    assert_redirected_to seasons_group_list_list_entries_path(@group, @list, tmdb_show_id: 136315, q: "the bear", recommendation: "So good")
    follow_redirect!
    assert_select "form#add_title input[name=recommendation][value=?]", "So good"
  end

  test "adding a season with a recommendation" do
    post group_list_list_entries_path(@group, @list), params: { tmdb_show_id: 136315, season: 1, recommendation: "So good" }

    assert_equal "So good", @list.list_entries.sole.recommendation
  end

  test "a recommendation that's too long is refused, keeping the search and what was typed" do
    long = "a" * 501

    assert_no_difference "ListEntry.count" do
      post group_list_list_entries_path(@group, @list), params: { tmdb_movie_id: 329865, q: "arrival", recommendation: long }
    end

    assert_redirected_to new_group_list_list_entry_path(@group, @list, q: "arrival", recommendation: long)
    assert_match(/Couldn't add Arrival: Recommendation is too long/, flash[:alert])
  end

  test "a title already in the catalog can be added by its ID" do
    movie = create(:movie, name: "Arrival", tmdb_id: nil)

    post group_list_list_entries_path(@group, @list), params: { title_id: movie.id }

    assert_equal "Added Arrival.", flash[:notice]
  end

  test "adding a title that's already active is refused" do
    @list.add(import_movie)

    assert_no_difference "ListEntry.count" do
      post group_list_list_entries_path(@group, @list), params: { tmdb_movie_id: 329865, q: "Arr" }
    end

    assert_redirected_to new_group_list_list_entry_path(@group, @list, q: "Arr")
    assert_equal "Arrival is already on this list.", flash[:alert]
  end

  test "when TMDB fails while adding, nothing is added and the search says so" do
    FakeTmdb.unreachable = true

    assert_no_difference [ "Title.count", "ListEntry.count" ] do
      post group_list_list_entries_path(@group, @list), params: { tmdb_movie_id: 329865, q: "arrival" }
    end

    assert_redirected_to new_group_list_list_entry_path(@group, @list, q: "arrival")
    assert_equal "Couldn't reach TMDB just now. Please try again.", flash[:alert]
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
    assert_select "p", text: /Series · 2026/
    assert_select "p", text: /In progress · Last watched Oct 12/
    assert_equal [ "Watched: #{season.episodes.first.label}", "#{season.episodes.second.label} Next", season.episodes.third.label ],
      css_select("ol li .episode-label").map { |item| item.text.gsub("✓", "").squish }
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
    # The TMDB results (the first list on the page).
    def result_names
      css_select("ul:first-of-type li .title-name").map(&:text)
    end

    def import_movie
      Tmdb::Importer.new(client: Tmdb::Client.new(token: "test")).import_movie(329865)
    end
end
