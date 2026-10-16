require "test_helper"

class Tmdb::WatchProvidersTest < ActiveSupport::TestCase
  setup do
    @client = Tmdb::Client.new(token: "test")
    @cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    FakeTmdb.unreachable = false
  end

  test "a movie's US options, grouped into stream, rent, and buy" do
    providers = watch_providers(build(:movie, tmdb_id: 329865))

    assert providers.any?
    assert_equal "Paramount Plus Premium", providers.stream.first.name
    assert_includes providers.stream.map(&:name), "Kanopy"
    assert_includes providers.rent.map(&:name), "Apple TV Store"
    assert_includes providers.buy.map(&:name), "Amazon Video"
    assert providers.stream.first.logo_path.start_with?("/")
    assert_equal "https://www.themoviedb.org/movie/329865-arrival/watch?locale=US", providers.link
  end

  test "a season uses its show's options" do
    providers = watch_providers(build(:season, tmdb_id: 136315, season: 2))

    assert_equal [ "Disney Plus", "Hulu", "YouTube TV" ].sort, providers.stream.map(&:name).sort
    assert_empty providers.rent
  end

  test "a title available nowhere in the US has no options" do
    assert_not watch_providers(build(:movie, tmdb_id: 1)).any?
  end

  test "answers are cached, so TMDB isn't asked again for a while" do
    movie = build(:movie, tmdb_id: 329865)
    watch_providers(movie)
    FakeTmdb.unreachable = true

    assert watch_providers(movie).any?
  end

  test "when TMDB can't be reached there's no answer, rather than an error" do
    FakeTmdb.unreachable = true

    assert_nil watch_providers(build(:movie, tmdb_id: 329865))
  end

  test "a title entered by hand isn't looked up" do
    assert_nil watch_providers(build(:movie, tmdb_id: nil))
  end

  private
    def watch_providers(title)
      Tmdb::WatchProviders.for(title, client: @client, cache: @cache)
    end
end
