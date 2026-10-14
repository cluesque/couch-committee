require "test_helper"

class ListEntryTest < ActiveSupport::TestCase
  test "factory builds a valid, not-yet-started entry" do
    entry = build(:list_entry)

    assert entry.valid?
    assert entry.not_started?
  end

  test "factory builds a valid cancelled entry" do
    assert build(:list_entry, :cancelled).valid?
  end

  test "a cancelled entry records when it was cancelled" do
    assert_not build(:list_entry, state: :cancelled, cancelled_at: nil).valid?
  end

  test "cancelling keeps the entry, with when and why" do
    travel_to Time.zone.local(2026, 10, 14, 21, 0) do
      entry = create(:list_entry, state: :in_progress)

      assert entry.cancel(note: "Too grim for a weeknight.")

      entry.reload
      assert entry.cancelled?
      assert_equal Time.zone.local(2026, 10, 14, 21, 0), entry.cancelled_at
      assert_equal "Too grim for a weeknight.", entry.cancel_note
    end
  end

  test "the cancel note is optional" do
    entry = create(:list_entry)

    entry.cancel(note: "  ")

    assert entry.reload.cancelled?
    assert_nil entry.cancel_note
  end

  test "requires a whole-number sequence" do
    assert_not build(:list_entry, sequence: nil).valid?
    assert_not build(:list_entry, sequence: 1.5).valid?
  end

  test "rejects an unknown state" do
    assert_not build(:list_entry, state: "abandoned").valid?
  end

  test "active means not started or in progress" do
    entries = %i[ not_started in_progress watched ].index_with { |state| create(:list_entry, state: state) }
    entries[:cancelled] = create(:list_entry, :cancelled)

    assert_equal entries.values_at(:not_started, :in_progress).sort, ListEntry.active.sort
    assert_equal [ true, true, false, false ], entries.values.map(&:active?)
  end

  test "a title can only be active once per playlist" do
    existing = create(:list_entry, state: :in_progress)

    duplicate = build(:list_entry, play_list: existing.play_list, title: existing.title)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:title], "is already on this playlist"
  end

  test "the database also refuses a second active entry" do
    existing = create(:list_entry)
    duplicate = build(:list_entry, play_list: existing.play_list, title: existing.title)

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save(validate: false) }
  end

  test "a title can be re-added once its earlier entry is watched or cancelled" do
    play_list, title = create(:play_list), create(:movie)
    create(:list_entry, play_list: play_list, title: title, state: :watched)
    create(:list_entry, :cancelled, play_list: play_list, title: title)

    assert build(:list_entry, play_list: play_list, title: title).valid?
  end

  test "the same title can be active on different playlists" do
    existing = create(:list_entry)

    assert build(:list_entry, title: existing.title).valid?
  end

  test "next episode is the lowest-numbered one not yet watched on this entry" do
    entry = create(:list_entry, title: create(:season, episode_count: 3))
    first, second, _third = entry.title.episodes
    view(entry, second)

    assert_equal first, entry.next_episode

    view(entry, first)
    assert_equal 3, entry.reload.next_episode.number
  end

  test "viewings from an earlier watch-through don't count toward a rewatch" do
    season = create(:season, episode_count: 2)
    earlier = create(:list_entry, title: season, state: :watched)
    season.episodes.each { |episode| view(earlier, episode) }

    rewatch = create(:list_entry, play_list: earlier.play_list, title: season)

    assert_equal season.episodes.first, rewatch.next_episode
    assert_nil rewatch.last_viewed_on
  end

  test "viewed? is about this entry's viewings only" do
    season = create(:season, episode_count: 2)
    entry = create(:list_entry, title: season)
    other = create(:list_entry, title: season)
    view(other, season.episodes.second)
    view(entry, season.episodes.first)

    assert entry.viewed?(season.episodes.first)
    assert_not entry.viewed?(season.episodes.second)
  end

  test "last viewed is the latest viewing date" do
    entry = create(:list_entry, title: create(:season, episode_count: 2))
    view(entry, entry.title.episodes.second, on: Date.new(2026, 10, 12))
    view(entry, entry.title.episodes.first, on: Date.new(2026, 10, 1))

    assert_equal Date.new(2026, 10, 12), entry.last_viewed_on
  end

  test "upcoming when everything left to watch comes out after today" do
    travel_to Date.new(2026, 10, 14) do
      season = create(:season, episode_count: 0)
      aired = create(:episode, title: season, number: 1, available_on: Date.new(2026, 10, 1))
      create(:episode, title: season, number: 2, available_on: Date.new(2026, 10, 21))
      entry = create(:list_entry, title: season)

      assert_not entry.upcoming?, "episode 1 is out"

      view(entry, aired)
      assert entry.reload.upcoming?
    end
  end

  test "not upcoming once something left is out today" do
    travel_to Date.new(2026, 10, 14) do
      entry = create(:list_entry, title: create(:season, episode_count: 1))
      entry.title.episodes.first.update!(available_on: Date.new(2026, 10, 14))

      assert_not entry.upcoming?
    end
  end

  test "an episode without a date counts as available" do
    entry = create(:list_entry, title: create(:season, episode_count: 1))
    entry.title.episodes.first.update!(available_on: nil)

    assert_not entry.upcoming?
  end

  test "a movie releasing later is upcoming" do
    travel_to Date.new(2026, 10, 14) do
      movie = create(:movie)
      movie.episodes.first.update!(available_on: Date.new(2026, 12, 25))

      assert create(:list_entry, title: movie).upcoming?
    end
  end

  test "nothing left to watch is not upcoming" do
    entry = create(:list_entry)
    view(entry, entry.title.episodes.first)

    assert_nil entry.next_episode
    assert_not entry.upcoming?
  end

  private
    def view(entry, episode, on: Date.new(2026, 10, 14))
      create(:viewing, list_entry: entry, episode: episode, date: on)
    end
end
