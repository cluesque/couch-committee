require "test_helper"

class WatchRemoverTest < ActiveSupport::TestCase
  setup do
    @group = create(:group)
    @list = create(:list, group: @group)
  end

  test "unwatching a mid-season episode takes it out of the watch-through" do
    season = create(:season, episode_count: 3)
    entry = @list.add(season)
    record season.episodes.first
    second = record(season.episodes.second).sole

    WatchRemover.call(second)

    assert_not Viewing.exists?(second.id)
    assert entry.reload.in_progress?
    assert_equal season.episodes.second, entry.next_episode
  end

  test "unwatching the only episode watched puts the entry back to not started" do
    season = create(:season, episode_count: 3)
    entry = @list.add(season)

    WatchRemover.call(record(season.episodes.first).sole)

    assert entry.reload.not_started?
  end

  test "unwatching part of a finished season reopens it on the list" do
    season = create(:season, episode_count: 2)
    entry = @list.add(season)
    record season.episodes.first
    last = record(season.episodes.second).sole
    assert entry.reload.watched?

    WatchRemover.call(last)

    assert entry.reload.in_progress?
    assert_includes @list.list_entries.active, entry
  end

  test "unwatching a movie puts it back on the list, not started" do
    movie = create(:movie)
    entry = @list.add(movie)

    WatchRemover.call(record(movie.episodes.first).sole)

    assert entry.reload.not_started?
  end

  test "the watch is undone on every list it was recorded on" do
    movie = create(:movie)
    entries = [ @list.add(movie), create(:list, group: @group).add(movie) ]
    viewings = record(movie.episodes.first)

    removed = WatchRemover.call(viewings.first)

    assert_equal viewings.sort, removed.sort
    assert entries.map(&:reload).all?(&:not_started?)
  end

  test "watching the same episode on another date isn't undone" do
    season = create(:season, episode_count: 2)
    other_list = create(:list, group: @group)
    @list.add(season)
    elsewhere = other_list.add(season)
    first = record(season.episodes.first, on: Date.new(2026, 10, 1)).find { |viewing| viewing.list_entry.list == @list }
    WatchRecorder.call(group: @group, episode: season.episodes.first, date: Date.new(2026, 10, 9)) # a rewatch of it

    WatchRemover.call(first)

    assert_equal 1, elsewhere.viewings.count
  end

  test "another group's watch of the same episode on the same day isn't touched" do
    movie = create(:movie)
    @list.add(movie)
    theirs = create(:list).add(movie)
    WatchRecorder.call(group: theirs.list.group, episode: movie.episodes.first, date: Date.new(2026, 10, 1))

    WatchRemover.call(record(movie.episodes.first).sole)

    assert theirs.reload.watched?
  end

  test "a cancelled entry stays cancelled" do
    season = create(:season, episode_count: 2)
    entry = @list.add(season)
    viewing = record(season.episodes.first).sole
    entry.cancel

    WatchRemover.call(viewing)

    assert entry.reload.cancelled?
  end

  test "an earlier watch-through can't reopen while a rewatch of it is active" do
    movie = create(:movie)
    earlier = @list.add(movie)
    viewing = record(movie.episodes.first).sole
    @list.add(movie)

    error = assert_raises(WatchRemover::Refused) { WatchRemover.call(viewing) }

    assert_match(/already back on/, error.message)
    assert Viewing.exists?(viewing.id)
    assert earlier.reload.watched?
  end

  private
    def record(episode, on: Date.new(2026, 10, 1))
      WatchRecorder.call(group: @group, episode: episode, date: on).map { |entry| entry.viewings.find_by!(episode: episode, date: on) }
    end
end
