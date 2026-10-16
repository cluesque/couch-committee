require "test_helper"

class TmdbTest < ActiveSupport::TestCase
  test "image URLs combine the base URL, a size, and TMDB's image path" do
    assert_equal "#{Tmdb.image_base_url}w92/poster.jpg", Tmdb.image_url("/poster.jpg", "w92")
  end

  test "a title without an image has no image URL" do
    assert_nil Tmdb.image_url(nil, "w92")
    assert_nil Tmdb.image_url("", "w92")
  end
end
