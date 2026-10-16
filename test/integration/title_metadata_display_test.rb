require "test_helper"

# TMDB titles come from FakeTmdb's recordings (Arrival, and The Bear's first season).
class TitleMetadataDisplayTest < ActionDispatch::IntegrationTest
  setup do
    user = create(:user)
    @group = create(:group, members: [ user ])
    @list = create(:list, group: @group)
    importer = Tmdb::Importer.new(client: Tmdb::Client.new(token: "test"))
    @arrival = importer.import_movie(329865)
    @the_bear = importer.import_season(136315, 1)
    sign_in_as user
  end

  test "an entry's page shows a movie's poster, facts, genres, overview, and links" do
    get group_list_list_entry_path(@group, @list, @list.add(@arrival))

    assert_select "img.title-poster[src=?]", Tmdb.image_url(@arrival.poster_path, "w342")
    assert_select "p", text: /Movie · 2016 · 1h 56m · PG-13/
    assert_select "p", text: "Drama, Science Fiction, Mystery"
    assert_select "p.title-overview", text: @arrival.overview
    assert_select "a[href=?]", "https://www.imdb.com/title/tt2543164/", text: "IMDb"
    assert_select "a[href=?]", "https://www.themoviedb.org/movie/329865", text: "TMDB"
  end

  test "an entry's page shows a season's facts, and each episode's still and overview" do
    get group_list_list_entry_path(@group, @list, @list.add(@the_bear))

    assert_select "p", text: /Series · 2022 · TV-MA · Hulu/
    assert_select "a[href=?]", "https://www.themoviedb.org/tv/136315/season/1", text: "TMDB"
    assert_select "ol li img.episode-still", count: 8
    first = @the_bear.episodes.first
    assert_select "ol li:first-child img[src=?]", Tmdb.image_url(first.still_path, "w185")
    assert_select "ol li:first-child p", text: first.overview
  end

  test "a hand-entered title's page still reads well without metadata" do
    movie = create(:movie, name: "Home movie", tmdb_id: nil)
    movie.episodes.first.update!(available_on: Date.new(2019, 5, 1))

    get group_list_list_entry_path(@group, @list, @list.add(movie))

    assert_response :success
    assert_select "h1", "Home movie"
    assert_select "p", text: /Movie · 2019/
    assert_select "img.title-poster", count: 0
    assert_select "a", text: "IMDb", count: 0
    assert_select "p.title-overview", count: 0
  end

  test "a linked title offers a refresh, back to the page it's on" do
    entry = @list.add(@arrival)
    path = group_list_list_entry_path(@group, @list, entry)

    get path

    assert_select "form[action=?] input[name=return_to][value=?]", title_refresh_path(@arrival), path
    assert_select "a", text: "Find on TMDB", count: 0
  end

  test "a hand-entered title offers to find it on TMDB instead" do
    movie = create(:movie, name: "Home movie", tmdb_id: nil)
    path = group_list_list_entry_path(@group, @list, @list.add(movie))

    get path

    assert_select "a[href=?]", new_title_tmdb_link_path(movie, return_to: path), text: "Find on TMDB"
    assert_select "form[action=?]", title_refresh_path(movie), count: 0
  end

  test "list rows show a small poster, or a blank of the same size" do
    @list.add(@arrival)
    @list.add(create(:movie, name: "Home movie", tmdb_id: nil))

    get group_list_path(@group, @list)

    rows = css_select("ol > li")
    assert_equal Tmdb.image_url(@arrival.poster_path, "w92"), rows.first.at_css("img.poster-thumb")["src"]
    assert rows[1].at_css("span.poster-thumb")
  end

  test "history rows show a small poster" do
    @list.add(@arrival)
    WatchRecorder.call(group: @group, episode: @arrival.episodes.first, date: Date.new(2026, 10, 1))

    get group_list_history_path(@group, @list)

    assert_select "ol > li img.poster-thumb[src=?]", Tmdb.image_url(@arrival.poster_path, "w92")
  end

  test "the catalog shows small posters, and a title's page has the full header" do
    get titles_path
    assert_select ".list-group img.poster-thumb", count: 2

    get title_path(@the_bear)
    assert_select "img.title-poster"
    assert_select "p", text: /Series · 2022 · TV-MA · Hulu/
    assert_select "ol li img.episode-still", count: 8
  end
end
