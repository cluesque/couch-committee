require "test_helper"

class WatchRecorderTest < ActiveSupport::TestCase
  setup do
    @list = create(:list)
  end

  test "watching a movie checks it off" do
    movie = create(:movie)
    entry = @list.add(movie)

    record movie.episodes.first

    assert entry.reload.watched?
    assert_equal [ [ movie.episodes.first, Date.new(2026, 10, 14) ] ],
      entry.viewings.map { |viewing| [ viewing.episode, viewing.date ] }
  end

  test "watching a mid-season episode puts the season in progress and advances what's next" do
    season = create(:season, episode_count: 3)
    entry = @list.add(season)

    record season.episodes.first

    assert entry.reload.in_progress?
    assert_equal season.episodes.second, entry.next_episode
  end

  test "watching episodes out of order still finishes the season only when all are watched" do
    season = create(:season, episode_count: 3)
    entry = @list.add(season)

    record season.episodes.third
    record season.episodes.first
    assert entry.reload.in_progress?
    assert_equal season.episodes.second, entry.next_episode

    record season.episodes.second
    assert entry.reload.watched?
  end

  test "watching the season's last remaining episode finishes it and drops it from the active view" do
    season = create(:season, episode_count: 2)
    entry = @list.add(season)
    record season.episodes.first

    record season.episodes.second

    assert entry.reload.watched?
    assert_not_includes @list.list_entries.active, entry
  end

  test "the same title on another list is untouched" do
    movie = create(:movie)
    elsewhere = create(:list).add(movie)
    entry = @list.add(movie)

    record movie.episodes.first, entry: entry

    assert entry.reload.watched?
    assert elsewhere.reload.not_started?
    assert_empty elsewhere.viewings
  end

  test "a rewatch starts its own watch-through; the finished one is untouched" do
    season = create(:season, episode_count: 2)
    finished = create(:list_entry, list: @list, title: season, state: :watched)
    rewatch = @list.add(season)

    record season.episodes.first, entry: rewatch

    assert_empty finished.viewings
    assert rewatch.reload.in_progress?
  end

  test "nothing is recorded if any viewing is invalid" do
    movie = create(:movie)
    entry = @list.add(movie)

    assert_raises(ActiveRecord::RecordInvalid) { record movie.episodes.first, on: nil }

    assert entry.reload.not_started?
    assert_equal 0, Viewing.count
  end

  private
    # The title's only entry on @list, unless given.
    def record(episode, on: Date.new(2026, 10, 14), entry: @list.list_entries.active.find_by!(title: episode.title))
      WatchRecorder.call(entry, episode: episode, date: on)
    end
end
