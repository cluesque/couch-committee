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
end
