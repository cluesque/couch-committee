require "test_helper"

class Titles::WatchProvidersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as @user
    @arrival = Tmdb::Importer.new(client: Tmdb::Client.new(token: "test")).import_movie(329865)
  end

  teardown do
    FakeTmdb.unreachable = false
  end

  test "pages for TMDB titles load where to watch lazily" do
    get title_path(@arrival)

    assert_select "turbo-frame#where_to_watch[src=?][loading=lazy]", title_watch_providers_path(@arrival)
  end

  test "pages for hand-entered titles don't try" do
    get title_path(create(:movie, tmdb_id: nil))

    assert_select "turbo-frame#where_to_watch", count: 0
  end

  test "where to watch shows each service's logo, with JustWatch credited" do
    get title_watch_providers_path(@arrival)

    assert_response :success
    assert_equal [ "Stream", "Rent", "Buy" ], css_select("turbo-frame#where_to_watch dt").map(&:text)
    assert_select "img.provider-logo[alt=?][title=?]", "Kanopy", "Kanopy"
    assert_select "a[href=?]", "https://www.themoviedb.org/movie/329865-arrival/watch?locale=US", text: "More options"
    assert_select "a[href='https://www.justwatch.com/']", text: "JustWatch"
  end

  test "a title available nowhere says so quietly" do
    nowhere = create(:movie, tmdb_id: 1)

    get title_watch_providers_path(nowhere)

    assert_select "p", text: "Not available to stream, rent, or buy in the US right now."
  end

  test "a TMDB outage says so quietly, rather than erroring" do
    FakeTmdb.unreachable = true

    get title_watch_providers_path(@arrival)

    assert_response :success
    assert_select "p", text: "Couldn't check where to watch just now."
  end

  test "a hand-entered title has nothing to look up" do
    get title_watch_providers_path(create(:movie, tmdb_id: nil))

    assert_response :not_found
  end
end
