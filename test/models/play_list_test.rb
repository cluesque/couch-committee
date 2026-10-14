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

  test "belongs to a group, which can have several playlists" do
    group = create(:group)
    play_lists = create_list(:play_list, 2, group: group)

    assert_equal play_lists.sort, group.play_lists.sort
  end
end
