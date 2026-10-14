require "test_helper"

class TitleTest < ActiveSupport::TestCase
  test "a movie is a title with exactly one episode" do
    movie = create(:movie, name: "Arrival")

    assert movie.movie?
    assert_equal [ [ 1, "Arrival" ] ], movie.episodes.pluck(:number, :name)
  end

  test "a season is a series title with its season number and episodes in order" do
    season = create(:season, season: 2, episode_count: 3)

    assert season.series?
    assert_equal 2, season.season
    assert_equal [ 1, 2, 3 ], season.episodes.map(&:number)
  end

  test "full name includes the season when there is one" do
    assert_equal "Arrival", build(:movie, name: "Arrival").full_name
    assert_equal "The Bear: Season 3", build(:season, name: "The Bear", season: 3).full_name
  end

  test "requires a name" do
    assert_not build(:movie, name: "").valid?
  end

  test "rejects an unknown kind" do
    assert_not build(:movie, kind: "opera").valid?
  end

  test "a series title needs a season number" do
    assert_not build(:season, season: nil).valid?
  end

  test "a movie has no season number" do
    assert_not build(:movie, season: 1).valid?
  end

  test "season numbers are positive whole numbers" do
    assert_not build(:season, season: 0).valid?
    assert_not build(:season, season: 1.5).valid?
  end

  test "books and podcasts may or may not have a season" do
    assert build(:title, kind: :book, episodes: []).valid?
    assert build(:title, kind: :podcast, season: 3, episodes: []).valid?
  end
end
