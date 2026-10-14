require "test_helper"

class GroupMembershipTest < ActiveSupport::TestCase
  test "factory builds a valid membership" do
    assert build(:group_membership).valid?
  end

  test "a user can only be a member of a group once" do
    membership = create(:group_membership)

    assert_not build(:group_membership, group: membership.group, user: membership.user).valid?
  end

  test "a user can belong to several groups" do
    membership = create(:group_membership)

    assert build(:group_membership, user: membership.user).valid?
  end
end
