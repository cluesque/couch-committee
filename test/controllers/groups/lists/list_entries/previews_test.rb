require "test_helper"

# The preview of a search result before it's added, served by ListEntriesController#preview.
class Groups::Lists::ListEntries::PreviewsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @group = create(:group, members: [ @user ])
    @list = create(:list, group: @group, name: "Movie night")
    sign_in_as @user
  end

  teardown do
    FakeTmdb.unreachable = false
  end

  test "search results open a preview of each movie, or a one-season show" do
    get new_group_list_list_entry_path(@group, @list, q: "arrival")
    assert_select "button.result-details[name=tmdb_movie_id][value='329865'][formaction=?]",
      preview_group_list_list_entries_path(@group, @list)

    get new_group_list_list_entry_path(@group, @list, q: "baby reindeer")
    assert_select "button.result-details[name=tmdb_show_id][value='241259'][formaction=?]",
      preview_group_list_list_entries_path(@group, @list, season: 1)
  end

  test "a show with several seasons opens its season picker, where each season opens a preview" do
    get new_group_list_list_entry_path(@group, @list, q: "the bear")
    assert_select "button.result-details[value='136315'][formaction=?]", seasons_group_list_list_entries_path(@group, @list)

    get seasons_group_list_list_entries_path(@group, @list, tmdb_show_id: 136315)
    assert_select "button.result-details[name=season][value='1'][formaction=?]", preview_group_list_list_entries_path(@group, @list)
  end

  test "a movie's preview shows what its list entry would, without adding it to the catalog" do
    assert_no_difference [ "Title.count", "ListEntry.count" ] do
      get preview_group_list_list_entries_path(@group, @list, tmdb_movie_id: 329865, q: "arrival")
    end

    assert_response :success
    assert_select "h1", "Arrival"
    assert_select "p", text: /Movie · 2016 · 1h 56m · PG-13/
    assert_select "p.title-overview"
    assert_select "img.provider-logo[alt=Kanopy]"
    assert_select "button[form=add_title][name=tmdb_movie_id][value='329865']", "Add to Movie night"
    assert_select "a[href=?]", new_group_list_list_entry_path(@group, @list, q: "arrival"), text: "← Search results"
  end

  test "a season's preview lists its episodes" do
    get preview_group_list_list_entries_path(@group, @list, tmdb_show_id: 136315, season: 1)

    assert_select "ol li img.episode-still", count: 8
    assert_select "form#add_title input[name=tmdb_show_id][value='136315']"
    assert_select "button[form=add_title][name=season][value='1']", "Add to Movie night"
  end

  test "a season reached through the picker leads back to it" do
    get preview_group_list_list_entries_path(@group, @list, tmdb_show_id: 136315, season: 1, from: "seasons", q: "bear")

    assert_select "a[href=?]", seasons_group_list_list_entries_path(@group, @list, tmdb_show_id: 136315, q: "bear"),
      text: "← The Bear seasons"
  end

  test "a recommendation typed on the search page comes along to the preview" do
    post preview_group_list_list_entries_path(@group, @list), params: { tmdb_movie_id: 329865, q: "arrival", recommendation: "Pat loved it" }

    assert_redirected_to preview_group_list_list_entries_path(@group, @list, tmdb_movie_id: 329865, q: "arrival", recommendation: "Pat loved it")
    follow_redirect!
    assert_select "form#add_title input[name=recommendation][value=?]", "Pat loved it"
  end

  test "something already on the list says so instead of offering Add" do
    @list.add(Tmdb::Importer.new(client: Tmdb::Client.new(token: "test")).import_movie(329865))

    get preview_group_list_list_entries_path(@group, @list, tmdb_movie_id: 329865)

    assert_select "p", "Already on Movie night."
    assert_select "button[form=add_title]", count: 0
  end

  test "when TMDB can't be reached, the preview sends you back to search" do
    FakeTmdb.unreachable = true

    get preview_group_list_list_entries_path(@group, @list, tmdb_movie_id: 329865, q: "arrival")

    assert_redirected_to new_group_list_list_entry_path(@group, @list, q: "arrival")
    assert_equal "Couldn't reach TMDB just now. Please try again.", flash[:alert]
  end
end
