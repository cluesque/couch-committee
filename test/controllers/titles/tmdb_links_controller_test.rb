require "test_helper"

class Titles::TmdbLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as create(:user)
  end

  teardown do
    FakeTmdb.unreachable = false
  end

  test "finding a movie on TMDB searches by its name, showing only movies" do
    movie = create(:movie, name: "Arrival", tmdb_id: nil)

    get new_title_tmdb_link_path(movie, return_to: "/lists/1")

    assert_response :success
    assert_select "input[name=q][value=?]", "Arrival"
    assert_select "form input[name=tmdb_id][value='329865']"
    assert_select "form input[name=return_to][value='/lists/1']"
    assert_select "svg.kind-icon-series", count: 0
  end

  test "finding a season on TMDB shows only shows" do
    season = create(:season, name: "The Bear", season: 1, tmdb_id: nil)

    get new_title_tmdb_link_path(season)

    assert_select ".title-name", text: "The Bear"
    assert_select "svg.kind-icon-movie", count: 0
  end

  test "linking fills in the title from TMDB and returns to where it was asked from" do
    movie = create(:movie, name: "arrival", tmdb_id: nil)

    post title_tmdb_link_path(movie), params: { tmdb_id: 329865, return_to: "/lists/1" }

    assert_redirected_to "/lists/1"
    assert_equal "Linked Arrival to TMDB.", flash[:notice]
    assert_equal [ 329865, "Arrival" ], movie.reload.values_at(:tmdb_id, :name)
  end

  test "linking a season uses its own season number" do
    season = create(:season, name: "Bear", season: 2, episode_count: 0, tmdb_id: nil)

    post title_tmdb_link_path(season), params: { tmdb_id: 136315 }

    assert_redirected_to title_path(season)
    assert_equal [ 136315, 2, 10 ], [ season.reload.tmdb_id, season.season, season.episodes.count ]
  end

  test "linking to something already in the catalog is refused rather than duplicated" do
    Tmdb::Importer.new(client: Tmdb::Client.new(token: "test")).import_movie(329865)
    movie = create(:movie, name: "arrival", tmdb_id: nil)

    post title_tmdb_link_path(movie), params: { tmdb_id: 329865 }

    assert_redirected_to new_title_tmdb_link_path(movie)
    assert_equal "That's already in the catalog as Arrival, so linking would duplicate it.", flash[:alert]
    assert_nil movie.reload.tmdb_id
  end

  test "a season TMDB doesn't have can't be linked" do
    season = create(:season, name: "The Bear", season: 99, tmdb_id: nil)

    post title_tmdb_link_path(season), params: { tmdb_id: 136315 }

    assert_match(/may not have Season 99/, flash[:alert])
    assert_nil season.reload.tmdb_id
  end

  test "when TMDB can't be reached, the search says so" do
    FakeTmdb.unreachable = true

    get new_title_tmdb_link_path(create(:movie, tmdb_id: nil))

    assert_select ".alert-danger", "Couldn't reach TMDB just now. Please try again."
  end

  test "a title already linked to TMDB isn't offered for linking" do
    linked = Tmdb::Importer.new(client: Tmdb::Client.new(token: "test")).import_movie(329865)

    get new_title_tmdb_link_path(linked)

    assert_response :not_found
  end
end
