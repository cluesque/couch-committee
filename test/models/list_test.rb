require "test_helper"

class ListTest < ActiveSupport::TestCase
  test "factory builds a valid list" do
    assert build(:list).valid?
  end

  test "requires a name" do
    assert_not build(:list, name: "").valid?
  end

  test "description is optional" do
    assert build(:list, description: nil).valid?
  end

  test "adding titles appends them in order, after any earlier entries" do
    list = create(:list)
    create(:list_entry, list: list, sequence: 7, state: :watched)

    first = list.add(create(:movie))
    second = list.add(create(:season))

    assert_equal [ 8, 9 ], [ first.sequence, second.sequence ]
    assert first.not_started?
  end

  test "adding a title that's already active returns the invalid entry" do
    list = create(:list)
    movie = create(:movie)
    list.add(movie)

    entry = list.add(movie)

    assert_not entry.persisted?
    assert_includes entry.errors[:title], "is already on this list"
  end

  test "reorder puts active entries in the given order" do
    list = create(:list)
    a, b, c = 3.times.map { list.add(create(:movie)) }

    list.reorder([ c.id, a.id, b.id ])

    assert_equal [ c, a, b ], list.list_entries.active.order(:sequence).to_a
  end

  test "reorder accepts ids as strings, as they arrive in params" do
    list = create(:list)
    a, b = 2.times.map { list.add(create(:movie)) }

    list.reorder([ b.id.to_s, a.id.to_s ])

    assert_equal [ b, a ], list.list_entries.order(:sequence).to_a
  end

  test "reorder ignores entries that aren't active on this list" do
    list = create(:list)
    a, b = 2.times.map { list.add(create(:movie)) }
    watched = create(:list_entry, list: list, state: :watched, sequence: 99)
    elsewhere = create(:list_entry, sequence: 42)

    list.reorder([ elsewhere.id, watched.id, b.id, a.id ])

    assert_equal [ 1, 2 ], [ b.reload.sequence, a.reload.sequence ]
    assert_equal 99, watched.reload.sequence
    assert_equal 42, elsewhere.reload.sequence
  end

  test "an entry added since the list was loaded stays at the end" do
    list = create(:list)
    a, b = 2.times.map { list.add(create(:movie)) }
    newer = list.add(create(:movie))

    list.reorder([ b.id, a.id ])

    assert_equal [ b, a, newer ], list.list_entries.active.order(:sequence).to_a
  end

  test "history is every viewing plus each cancellation, most recent first" do
    list = create(:list)
    season = create(:season, episode_count: 3)
    list.add(season)
    movie = create(:movie)
    list.add(movie)
    first = watch(list, season.episodes.first, on: Date.new(2026, 10, 1))
    cancelled = travel_to(Time.zone.local(2026, 10, 5, 12)) { list.add(create(:movie)).tap(&:cancel) }
    second = watch(list, season.episodes.second, on: Date.new(2026, 10, 9))
    finished = watch(list, movie.episodes.first, on: Date.new(2026, 9, 20))
    list.add(create(:movie))

    assert_equal [ second, cancelled, first, finished ], list.history
  end

  test "history breaks same-day ties by which happened later" do
    list = create(:list)
    season = create(:season, episode_count: 2)
    list.add(season)
    earlier = travel_to(Time.zone.local(2026, 10, 9, 20)) { watch(list, season.episodes.first, on: Date.new(2026, 10, 9)) }
    later = travel_to(Time.zone.local(2026, 10, 9, 21)) { watch(list, season.episodes.second, on: Date.new(2026, 10, 9)) }

    assert_equal [ later, earlier ], list.history
  end

  test "belongs to a group, which can have several lists" do
    group = create(:group)
    lists = create_list(:list, 2, group: group)

    assert_equal lists.sort, group.lists.sort
  end

  private
    def watch(list, episode, on:)
      WatchRecorder.call(group: list.group, episode: episode, date: on)
      Viewing.where(episode: episode).sole
    end
end
