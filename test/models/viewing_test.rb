require "test_helper"

class ViewingTest < ActiveSupport::TestCase
  test "factory builds a valid viewing" do
    assert build(:viewing).valid?
  end

  test "requires a date" do
    assert_not build(:viewing, date: nil).valid?
  end

  test "the episode must belong to the entry's title" do
    viewing = build(:viewing, episode: create(:movie).episodes.first)

    assert_not viewing.valid?
    assert_includes viewing.errors[:episode], "isn't part of this entry's title"
  end

  test "is reachable from its entry and episode" do
    viewing = create(:viewing)

    assert_equal [ viewing ], viewing.list_entry.viewings
    assert_equal [ viewing ], viewing.episode.viewings
  end
end
