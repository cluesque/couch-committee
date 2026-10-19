require "test_helper"

class ListMembershipTest < ActiveSupport::TestCase
  test "factory builds a valid membership" do
    assert build(:list_membership).valid?
  end

  test "a user can only be on a list once" do
    membership = create(:list_membership)

    assert_not build(:list_membership, list: membership.list, user: membership.user).valid?
  end

  test "a user can be on several lists" do
    membership = create(:list_membership)

    assert build(:list_membership, user: membership.user).valid?
  end
end
