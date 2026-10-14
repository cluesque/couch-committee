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

  test "belongs to a group, which can have several playlists" do
    group = create(:group)
    play_lists = create_list(:play_list, 2, group: group)

    assert_equal play_lists.sort, group.play_lists.sort
  end
end
