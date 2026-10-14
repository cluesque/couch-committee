require "test_helper"

class EpisodeTest < ActiveSupport::TestCase
  test "factory builds a valid episode" do
    assert build(:episode).valid?
  end

  test "numbers are positive whole numbers" do
    assert_not build(:episode, number: nil).valid?
    assert_not build(:episode, number: 0).valid?
  end

  test "numbers are unique within a title" do
    season = create(:season, episode_count: 1)

    assert_not build(:episode, title: season, number: 1).valid?
    assert build(:episode, title: create(:season, episode_count: 0), number: 1).valid?
  end

  test "name and availability date are optional" do
    assert build(:episode, name: nil, available_on: nil).valid?
  end
end
