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

  test "requires a whole-number sequence" do
    assert_not build(:list_entry, sequence: nil).valid?
    assert_not build(:list_entry, sequence: 1.5).valid?
  end

  test "rejects an unknown state" do
    assert_not build(:list_entry, state: "abandoned").valid?
  end

  test "active means not started or in progress" do
    entries = %i[ not_started in_progress watched cancelled ].index_with { |state| create(:list_entry, state: state) }

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
end
