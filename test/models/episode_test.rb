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

  test "label is its number and name, or just its number" do
    assert_equal "3. Next", build(:episode, number: 3, name: "Next").label
    assert_equal "Episode 3", build(:episode, number: 3, name: "").label
  end

  test "full name is the episode with its title, or just the movie" do
    season = create(:season, name: "The Bear", season: 1, episode_count: 0)
    episode = create(:episode, title: season, number: 2, name: "Hands")

    assert_equal "The Bear · 2. Hands", episode.full_name
    assert_equal "Arrival", create(:movie, name: "Arrival").episodes.first.full_name
  end

  test "a movie's episode is labelled with the movie's title" do
    assert_equal "Arrival", create(:movie, name: "Arrival").episodes.first.label
  end

  test "a name that's just its number isn't repeated" do
    assert_equal "Episode 1", build(:episode, number: 1, name: "Episode 1").label
    assert_equal "Episode 1", build(:episode, number: 1, name: "episode 1").label
    assert_equal "2. Episode 1", build(:episode, number: 2, name: "Episode 1").label
  end

  test "name and availability date are optional" do
    assert build(:episode, name: nil, available_on: nil).valid?
  end
end
