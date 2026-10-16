require "test_helper"

class Tmdb::ClientTest < ActiveSupport::TestCase
  setup do
    @client = Tmdb::Client.new(token: "test-token")
  end

  teardown do
    FakeTmdb.unreachable = false
  end

  test "search finds movies and shows, most relevant first, leaving out people" do
    results = @client.search("arrival")

    assert_equal Tmdb::SearchResult.new(kind: "movie", tmdb_id: 329865, name: "Arrival", year: 2016,
      poster_path: results.first.poster_path, overview: results.first.overview), results.first
    assert results.first.poster_path.start_with?("/")
    assert results.first.overview.present?
    assert_equal %w[ movie ], results.map(&:kind).uniq
  end

  test "search results for a show are series, named and dated from TMDB's TV fields" do
    the_bear = @client.search("The Bear").first

    assert_equal [ "series", 136315, "The Bear", 2022 ], [ the_bear.kind, the_bear.tmdb_id, the_bear.name, the_bear.year ]
    assert_not_includes @client.search("The Bear").map(&:name), "Bart the Bear"
  end

  test "a search with no matches finds nothing" do
    assert_empty @client.search("no such title anywhere")
  end

  test "a movie's details include its IMDb ID and US release dates" do
    movie = @client.movie(329865)

    assert_equal [ "Arrival", "tt2543164", 116 ], movie.values_at("title", "imdb_id", "runtime")
    assert_equal [ "US" ], movie.dig("release_dates", "results").map { |country| country["iso_3166_1"] }
  end

  test "a show's details include its IMDb ID, US rating, and seasons" do
    show = @client.tv(136315)

    assert_equal "The Bear", show["name"]
    assert show.dig("external_ids", "imdb_id").start_with?("tt")
    assert_equal [ "US" ], show.dig("content_ratings", "results").map { |country| country["iso_3166_1"] }
    assert_includes show["seasons"].map { |season| season["season_number"] }, 1
  end

  test "a season's details include its episodes" do
    season = @client.season(136315, 1)

    assert_equal 8, season["episodes"].size
    assert_equal [ 1, "System" ], season["episodes"].first.values_at("episode_number", "name")
  end

  test "where to watch is by country, for movies and series" do
    assert_includes @client.watch_providers("movie", 329865).keys, "US"
    assert_includes @client.watch_providers("series", 136315).keys, "US"
  end

  test "requests carry the read access token" do
    @client.movie(329865)

    assert_equal "Bearer test-token", FakeTmdb.last_request.request_headers["Authorization"]
  end

  test "an error from TMDB raises Tmdb::Error" do
    error = assert_raises(Tmdb::Error) { @client.movie(1) }

    assert_equal "TMDB answered 404 for movie/1", error.message
  end

  test "an unreachable TMDB raises Tmdb::Error" do
    FakeTmdb.unreachable = true

    error = assert_raises(Tmdb::Error) { @client.search("arrival") }
    assert_match(/Couldn't reach TMDB/, error.message)
  end
end
