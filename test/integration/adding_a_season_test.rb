require "test_helper"

class AddingASeasonTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as create(:user)
  end

  test "the catalog links to the season form" do
    get titles_path

    assert_select "a[href=?]", new_title_path(kind: "series"), text: "Add a season"
  end

  test "season form starts with one numbered episode and a template for more" do
    get new_title_path(kind: "series")

    assert_response :success
    assert_select "h1", "Add a season"
    assert_select "input[name=?][value=?]", "title[kind]", "series"
    assert_select "input[name=?]", "title[season]"
    assert_select "input[name=?][value=?]", "title[episodes_attributes][0][number]", "1"
    assert_select "template input[name=?]", "title[episodes_attributes][NEW_EPISODE][name]"
  end

  test "adding a season creates its title and episodes" do
    assert_difference [ "Title.count" ], 1 do
      assert_difference "Episode.count", 2 do
        post titles_path, params: season_params(
          { number: "1", name: "Tomorrow", available_on: "2026-06-26" },
          { number: "2", name: "Next", available_on: "" }
        )
      end
    end

    season = Title.last
    assert_redirected_to title_path(season)
    assert_equal "Added The Bear: Season 3.", flash[:notice]
    assert season.series?
    assert_equal [ [ 1, "Tomorrow", Date.new(2026, 6, 26) ], [ 2, "Next", nil ] ],
      season.episodes.map { |episode| [ episode.number, episode.name, episode.available_on ] }
  end

  test "a season needs a season number" do
    assert_no_difference "Title.count" do
      post titles_path, params: season_params({ number: "1" }, season: "")
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger li", "Season can't be blank"
    assert_select "h1", "Add a season"
  end

  test "two episodes can't share a number" do
    assert_no_difference "Title.count" do
      post titles_path, params: season_params({ number: "1" }, { number: "1" })
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger li", "Episode numbers must be unique"
  end

  private
    def season_params(*episodes, season: "3")
      episodes_attributes = episodes.each_with_index.to_h { |episode, index| [ index.to_s, episode ] }
      { title: { kind: "series", name: "The Bear", season: season, episodes_attributes: episodes_attributes } }
    end
end
