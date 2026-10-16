require "test_helper"

class TitlesHelperTest < ActionView::TestCase
  test "each kind gets its own labelled icon" do
    movie = kind_icon(build(:movie))
    series = kind_icon(build(:season))

    assert_includes movie, 'aria-label="Movie"'
    assert_includes movie, "kind-icon-movie"
    assert_includes series, 'aria-label="Series"'
    assert_includes series, "kind-icon-series"
    assert_not_equal movie[/<path[^>]*>/], series[/<path[^>]*>/]
  end

  test "a decorative icon is hidden from screen readers" do
    icon = kind_icon(build(:movie), decorative: true)

    assert_includes icon, 'aria-hidden="true"'
    assert_not_includes icon, "aria-label"
    assert_not_includes icon, "<title>"
  end

  test "books and podcasts have icons too" do
    assert_includes kind_icon(build(:title, kind: :book, episodes: [])), 'aria-label="Book"'
    assert_includes kind_icon(build(:title, kind: :podcast, episodes: [])), 'aria-label="Podcast"'
  end

  test "runtime reads as hours and minutes" do
    assert_equal "1h 56m", runtime(116)
    assert_equal "28m", runtime(28)
    assert_equal "2h", runtime(120)
    assert_nil runtime(nil)
  end

  test "title facts leave out what's unknown" do
    movie = build(:movie, runtime_minutes: 116, rating: "PG-13")
    movie.episodes.first.available_on = Date.new(2016, 11, 10)

    assert_equal "Movie · 2016 · 1h 56m · PG-13", title_facts(movie)
    assert_equal "Series", title_facts(build(:season, episode_count: 0))
  end
end
