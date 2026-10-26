require "test_helper"

class ViewingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @movie_night = create(:list, members: [ @user ], name: "Movie night")
    @just_me = create(:list, members: [ @user ], name: "Just Me")
    sign_in_as @user
  end

  test "the account menu links to it" do
    get root_path

    assert_select ".dropdown-menu a[href=?]", viewings_path, text: "Recently watched"
  end

  test "recent watches on all my lists, newest first, each naming its list" do
    season = create(:season, name: "The Bear", season: 3, episode_count: 0)
    first = create(:episode, title: season, number: 1, name: "Tomorrow")
    arrival = create(:movie, name: "Arrival")
    bear = @movie_night.add(season)
    watch bear, first, Date.new(2026, 10, 1)
    watch @just_me.add(arrival), arrival.episodes.first, Date.new(2026, 10, 9)
    elsewhere = create(:list).add(create(:movie, name: "Not mine"))
    watch elsewhere, elsewhere.title.episodes.first, Date.new(2026, 10, 12)

    get viewings_path

    assert_response :success
    rows = css_select("ol > li").map do |row|
      [ row.at_css(".fw-medium").text, row.at_css("div.small.text-body-secondary")&.text, row.at_css(".watch-lists").text.squish,
        row.at_css("small").text ]
    end
    assert_equal [
      [ "Arrival", nil, "Just Me", "Oct 09" ],
      [ "The Bear: Season 3", "1. Tomorrow", "Movie night", "Oct 01" ]
    ], rows
    assert_select ".watch-lists a[href=?]", list_list_entry_path(@movie_night, bear)
  end

  test "one watch recorded on several lists is one row naming each" do
    arrival = create(:movie, name: "Arrival")
    [ @movie_night, @just_me ].each { |list| watch list.add(arrival), arrival.episodes.first, Date.new(2026, 10, 9) }

    get viewings_path

    assert_equal [ "Just Me, Movie night" ], css_select(".watch-lists").map { |lists| lists.text.squish }
  end

  test "watches on a deleted list aren't shown" do
    arrival = create(:movie, name: "Arrival")
    watch @movie_night.add(arrival), arrival.episodes.first, Date.new(2026, 10, 9)
    @movie_night.soft_delete

    get viewings_path

    assert_select "ol", count: 0
    assert_select "p", text: /Nothing watched yet/
  end

  private
    def watch(entry, episode, date)
      WatchRecorder.call(entry, episode: episode, date: date)
    end
end
