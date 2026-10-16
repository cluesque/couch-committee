require "test_helper"

class Titles::RefreshesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as create(:user)
    @season = Tmdb::Importer.new(client: Tmdb::Client.new(token: "test")).import_season(136315, 1)
  end

  teardown do
    FakeTmdb.unreachable = false
  end

  test "refreshing a linked title re-imports it and returns to the page it was asked from" do
    @season.episodes.where(number: 2..).destroy_all

    post title_refresh_path(@season), params: { return_to: "/somewhere/in/the/app" }

    assert_redirected_to "/somewhere/in/the/app"
    assert_equal "Refreshed The Bear from TMDB.", flash[:notice]
    assert_equal 8, @season.episodes.count
  end

  test "without a return path, refreshing lands on the title's page" do
    post title_refresh_path(@season)

    assert_redirected_to title_path(@season)
  end

  test "only paths within the app are returned to" do
    post title_refresh_path(@season), params: { return_to: "//evil.example.com/" }
    assert_redirected_to title_path(@season)

    post title_refresh_path(@season), params: { return_to: "https://evil.example.com/" }
    assert_redirected_to title_path(@season)
  end

  test "when TMDB can't be reached, the title is left as it was" do
    FakeTmdb.unreachable = true

    post title_refresh_path(@season)

    assert_equal "Couldn't reach TMDB just now. Please try again.", flash[:alert]
  end

  test "a hand-entered title has nothing to refresh from" do
    post title_refresh_path(create(:movie, tmdb_id: nil))

    assert_response :not_found
  end
end
