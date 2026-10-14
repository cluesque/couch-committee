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

  test "invite adds an existing user" do
    group, sam = create(:group), create(:user, email: "sam@example.com")

    assert_no_difference "User.count" do
      group.invite("Sam@Example.com")
    end
    assert_equal [ sam ], group.users
  end

  test "invite creates a not-yet-signed-in user for a new email" do
    group = create(:group)

    group.invite("kim@example.com")

    kim = User.find_by!(email: "kim@example.com")
    assert_equal [ kim ], group.users
    assert_nil kim.google_id
  end

  test "invite refuses an invalid email without creating anyone" do
    group = create(:group)

    assert_no_difference [ "User.count", "GroupMembership.count" ] do
      error = assert_raises(ActiveRecord::RecordInvalid) { group.invite("not an email") }
      assert_equal [ "Email is invalid" ], error.record.errors.full_messages
    end
  end

  test "invite refuses someone who's already a member" do
    sam = create(:user)
    group = create(:group, members: [ sam ])

    error = assert_raises(ActiveRecord::RecordInvalid) { group.invite(sam.email) }
    assert_equal [ "User is already a member" ], error.record.errors.full_messages
  end
end
