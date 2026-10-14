require "test_helper"

class WatchRecorderTest < ActiveSupport::TestCase
  setup do
    @group = create(:group)
    @play_list = create(:play_list, group: @group)
  end

  test "watching a movie checks it off" do
    movie = create(:movie)
    entry = @play_list.add(movie)

    record movie.episodes.first

    assert entry.reload.watched?
    assert_equal [ [ movie.episodes.first, Date.new(2026, 10, 14), @group ] ],
      entry.viewings.map { |viewing| [ viewing.episode, viewing.date, viewing.group ] }
  end

  test "watching a mid-season episode puts the season in progress and advances what's next" do
    season = create(:season, episode_count: 3)
    entry = @play_list.add(season)

    record season.episodes.first

    assert entry.reload.in_progress?
    assert_equal season.episodes.second, entry.next_episode
  end

  test "watching episodes out of order still finishes the season only when all are watched" do
    season = create(:season, episode_count: 3)
    entry = @play_list.add(season)

    record season.episodes.third
    record season.episodes.first
    assert entry.reload.in_progress?
    assert_equal season.episodes.second, entry.next_episode

    record season.episodes.second
    assert entry.reload.watched?
  end

  test "watching the season's last remaining episode finishes it and drops it from the active view" do
    season = create(:season, episode_count: 2)
    entry = @play_list.add(season)
    record season.episodes.first

    record season.episodes.second

    assert entry.reload.watched?
    assert_not_includes @play_list.list_entries.active, entry
  end

  test "a watch checks the title off on every playlist in the group" do
    movie = create(:movie)
    other_play_list = create(:play_list, group: @group)
    entries = [ @play_list.add(movie), other_play_list.add(movie) ]

    recorded = record movie.episodes.first

    assert_equal entries.sort, recorded.sort
    assert entries.map(&:reload).all?(&:watched?)
    assert_equal 2, Viewing.count
  end

  test "another group's playlists are untouched" do
    movie = create(:movie)
    elsewhere = create(:play_list).add(movie)
    @play_list.add(movie)

    record movie.episodes.first

    assert elsewhere.reload.not_started?
    assert_empty elsewhere.viewings
  end

  test "finished and cancelled entries are untouched; only the active watch-through counts" do
    season = create(:season, episode_count: 2)
    finished = create(:list_entry, play_list: @play_list, title: season, state: :watched)
    cancelled = create(:list_entry, :cancelled, play_list: create(:play_list, group: @group), title: season)
    rewatch = @play_list.add(season)

    record season.episodes.first

    assert_empty finished.viewings
    assert_empty cancelled.viewings
    assert rewatch.reload.in_progress?
  end

  test "a title that isn't active on any of the group's playlists records nothing" do
    assert_empty record(create(:movie).episodes.first)
    assert_equal 0, Viewing.count
  end

  test "nothing is recorded if any viewing is invalid" do
    movie = create(:movie)
    entry = @play_list.add(movie)

    assert_raises(ActiveRecord::RecordInvalid) { record movie.episodes.first, on: nil }

    assert entry.reload.not_started?
    assert_equal 0, Viewing.count
  end

  private
    def record(episode, on: Date.new(2026, 10, 14))
      WatchRecorder.call(group: @group, episode: episode, date: on)
    end
end
