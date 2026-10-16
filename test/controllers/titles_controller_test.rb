require "test_helper"

class TitlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as create(:user)
  end

  test "lists the whole catalog by name and season" do
    create(:season, name: "The Bear", season: 2)
    create(:movie, name: "Arrival")
    create(:season, name: "The Bear", season: 1)

    get titles_path

    assert_response :success
    assert_equal [ "Arrival", "The Bear: Season 1", "The Bear: Season 2" ],
      css_select(".list-group-item .title-name").map(&:text)
  end

  test "is reachable from the home page" do
    get root_path

    assert_select "a[href=?]", titles_path, text: "Browse titles"
  end

  test "a season's page lists its episodes in order" do
    season = create(:season, name: "The Bear", season: 3, episode_count: 0)
    create(:episode, title: season, number: 2, name: "Next", available_on: Date.new(2026, 6, 26))
    create(:episode, title: season, number: 1, name: "Tomorrow", available_on: nil)

    get title_path(season)

    assert_response :success
    assert_select "h1", "The Bear: Season 3"
    assert_equal [ "1. Tomorrow", "2. Next" ], css_select("li .episode-label").map { |item| item.text.squish }
    assert_select "li small", "Jun 26"
  end

  test "a movie's page shows its release date" do
    movie = create(:movie, name: "Arrival")
    movie.episodes.first.update!(available_on: Date.new(2016, 11, 11))

    get title_path(movie)

    assert_select "h1", "Arrival"
    assert_select "p", "Released November 11, 2016"
  end
end
