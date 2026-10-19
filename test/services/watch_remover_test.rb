require "test_helper"

class WatchRemoverTest < ActiveSupport::TestCase
  setup do
    @list = create(:list)
  end

  test "unwatching a mid-season episode takes it out of the watch-through" do
    season = create(:season, episode_count: 3)
    entry = @list.add(season)
    record season.episodes.first
    second = record(season.episodes.second)

    WatchRemover.call(second)

    assert_not Viewing.exists?(second.id)
    assert entry.reload.in_progress?
    assert_equal season.episodes.second, entry.next_episode
  end

  test "unwatching the only episode watched puts the entry back to not started" do
    season = create(:season, episode_count: 3)
    entry = @list.add(season)

    WatchRemover.call(record(season.episodes.first))

    assert entry.reload.not_started?
  end

  test "unwatching part of a finished season reopens it on the list" do
    season = create(:season, episode_count: 2)
    entry = @list.add(season)
    record season.episodes.first
    last = record(season.episodes.second)
    assert entry.reload.watched?

    WatchRemover.call(last)

    assert entry.reload.in_progress?
    assert_includes @list.list_entries.active, entry
  end

  test "unwatching a movie puts it back on the list, not started" do
    movie = create(:movie)
    entry = @list.add(movie)

    WatchRemover.call(record(movie.episodes.first))

    assert entry.reload.not_started?
  end

  test "the same watch on another list isn't undone" do
    movie = create(:movie)
    @list.add(movie)
    elsewhere = create(:list).add(movie)
    WatchRecorder.call(elsewhere, episode: movie.episodes.first, date: Date.new(2026, 10, 1))

    WatchRemover.call(record(movie.episodes.first))

    assert elsewhere.reload.watched?
  end

  test "a cancelled entry stays cancelled" do
    season = create(:season, episode_count: 2)
    entry = @list.add(season)
    viewing = record(season.episodes.first)
    entry.cancel

    WatchRemover.call(viewing)

    assert entry.reload.cancelled?
  end

  test "an earlier watch-through can't reopen while a rewatch of it is active" do
    movie = create(:movie)
    earlier = @list.add(movie)
    viewing = record(movie.episodes.first)
    @list.add(movie)

    error = assert_raises(WatchRemover::Refused) { WatchRemover.call(viewing) }

    assert_match(/already back on/, error.message)
    assert Viewing.exists?(viewing.id)
    assert earlier.reload.watched?
  end

  private
    def record(episode, on: Date.new(2026, 10, 1))
      WatchRecorder.call(@list.list_entries.active.find_by!(title: episode.title), episode: episode, date: on)
    end
end
