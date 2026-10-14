require "test_helper"

class GroupTest < ActiveSupport::TestCase
  test "factory builds a valid group" do
    assert build(:group).valid?
  end

  test "requires a name" do
    assert_not build(:group, name: " ").valid?
  end

  test "has members through memberships" do
    pat, sam = create_list(:user, 2)
    group = create(:group, members: [ pat, sam ])

    assert_equal [ pat, sam ].sort, group.users.sort
    assert_equal [ group ], pat.groups
  end
end
