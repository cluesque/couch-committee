require "test_helper"

class PlayListTest < ActiveSupport::TestCase
  test "factory builds a valid playlist" do
    assert build(:play_list).valid?
  end

  test "requires a name" do
    assert_not build(:play_list, name: "").valid?
  end

  test "description is optional" do
    assert build(:play_list, description: nil).valid?
  end

  test "adding titles appends them in order, after any earlier entries" do
    play_list = create(:play_list)
    create(:list_entry, play_list: play_list, sequence: 7, state: :watched)

    first = play_list.add(create(:movie))
    second = play_list.add(create(:season))

    assert_equal [ 8, 9 ], [ first.sequence, second.sequence ]
    assert first.not_started?
  end

  test "adding a title that's already active returns the invalid entry" do
    play_list = create(:play_list)
    movie = create(:movie)
    play_list.add(movie)

    entry = play_list.add(movie)

    assert_not entry.persisted?
    assert_includes entry.errors[:title], "is already on this playlist"
  end

  test "reorder puts active entries in the given order" do
    play_list = create(:play_list)
    a, b, c = 3.times.map { play_list.add(create(:movie)) }

    play_list.reorder([ c.id, a.id, b.id ])

    assert_equal [ c, a, b ], play_list.list_entries.active.order(:sequence).to_a
  end

  test "reorder accepts ids as strings, as they arrive in params" do
    play_list = create(:play_list)
    a, b = 2.times.map { play_list.add(create(:movie)) }

    play_list.reorder([ b.id.to_s, a.id.to_s ])

    assert_equal [ b, a ], play_list.list_entries.order(:sequence).to_a
  end

  test "reorder ignores entries that aren't active on this playlist" do
    play_list = create(:play_list)
    a, b = 2.times.map { play_list.add(create(:movie)) }
    watched = create(:list_entry, play_list: play_list, state: :watched, sequence: 99)
    elsewhere = create(:list_entry, sequence: 42)

    play_list.reorder([ elsewhere.id, watched.id, b.id, a.id ])

    assert_equal [ 1, 2 ], [ b.reload.sequence, a.reload.sequence ]
    assert_equal 99, watched.reload.sequence
    assert_equal 42, elsewhere.reload.sequence
  end

  test "an entry added since the list was loaded stays at the end" do
    play_list = create(:play_list)
    a, b = 2.times.map { play_list.add(create(:movie)) }
    newer = play_list.add(create(:movie))

    play_list.reorder([ b.id, a.id ])

    assert_equal [ b, a, newer ], play_list.list_entries.active.order(:sequence).to_a
  end

  test "history is every viewing plus each cancellation, most recent first" do
    play_list = create(:play_list)
    season = create(:season, episode_count: 3)
    play_list.add(season)
    movie = create(:movie)
    play_list.add(movie)
    first = watch(play_list, season.episodes.first, on: Date.new(2026, 10, 1))
    cancelled = travel_to(Time.zone.local(2026, 10, 5, 12)) { play_list.add(create(:movie)).tap(&:cancel) }
    second = watch(play_list, season.episodes.second, on: Date.new(2026, 10, 9))
    finished = watch(play_list, movie.episodes.first, on: Date.new(2026, 9, 20))
    play_list.add(create(:movie))

    assert_equal [ second, cancelled, first, finished ], play_list.history
  end

  test "history breaks same-day ties by which happened later" do
    play_list = create(:play_list)
    season = create(:season, episode_count: 2)
    play_list.add(season)
    earlier = travel_to(Time.zone.local(2026, 10, 9, 20)) { watch(play_list, season.episodes.first, on: Date.new(2026, 10, 9)) }
    later = travel_to(Time.zone.local(2026, 10, 9, 21)) { watch(play_list, season.episodes.second, on: Date.new(2026, 10, 9)) }

    assert_equal [ later, earlier ], play_list.history
  end

  test "belongs to a group, which can have several playlists" do
    group = create(:group)
    play_lists = create_list(:play_list, 2, group: group)

    assert_equal play_lists.sort, group.play_lists.sort
  end

  private
    def watch(play_list, episode, on:)
      WatchRecorder.call(group: play_list.group, episode: episode, date: on)
      Viewing.where(episode: episode).sole
    end
end
