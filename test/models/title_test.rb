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

  test "a TMDB movie can be in the catalog only once" do
    create(:movie, tmdb_id: 329865)

    duplicate = build(:movie, tmdb_id: 329865)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:tmdb_id], "is already in the catalog"
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save(validate: false) }
  end

  test "each season of a TMDB show can be in the catalog once" do
    create(:season, tmdb_id: 136315, season: 1)

    assert build(:season, tmdb_id: 136315, season: 2).valid?
    assert_raises(ActiveRecord::RecordNotUnique) { build(:season, tmdb_id: 136315, season: 1).save(validate: false) }
  end

  test "titles entered by hand have no TMDB ID, and don't collide" do
    create(:movie, tmdb_id: nil)

    assert build(:movie, tmdb_id: nil).valid?
  end

  test "links to IMDb and TMDB come from the stored IDs" do
    movie = build(:movie, tmdb_id: 329865, imdb_id: "tt2543164")
    season = build(:season, tmdb_id: 136315, season: 3, imdb_id: "tt14452776")

    assert_equal "https://www.imdb.com/title/tt2543164/", movie.imdb_url
    assert_equal "https://www.themoviedb.org/movie/329865", movie.tmdb_url
    assert_equal "https://www.imdb.com/title/tt14452776/", season.imdb_url
    assert_equal "https://www.themoviedb.org/tv/136315/season/3", season.tmdb_url
    assert_nil build(:movie).imdb_url
    assert_nil build(:movie).tmdb_url
  end

  test "requires a name" do
    assert_not build(:movie, name: "").valid?
  end

  test "rejects an unknown kind" do
    assert_not build(:movie, kind: "opera").valid?
  end

  test "a movie has exactly one episode" do
    assert_not build(:movie, episodes: []).valid?

    movie = build(:movie)
    movie.episodes.build(number: 2)
    assert_not movie.valid?
    assert_includes movie.errors[:base], "A movie has exactly one episode"
  end

  test "episode numbers are unique, even before anything is saved" do
    season = build(:season, episode_count: 0)
    2.times { season.episodes.build(number: 1) }

    assert_not season.valid?
    assert_includes season.errors[:base], "Episode numbers must be unique"
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
