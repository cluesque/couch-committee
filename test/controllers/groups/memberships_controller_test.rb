require "test_helper"

class Groups::MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @group = create(:group, members: [ @user ])
    sign_in_as @user
  end

  test "adding someone who already has an account" do
    sam = create(:user, email: "sam@example.com")

    post group_memberships_path(@group), params: { email: "sam@example.com" }

    assert_redirected_to group_path(@group)
    assert_equal "Added sam@example.com.", flash[:notice]
    assert_includes @group.users.reload, sam
  end

  test "adding someone new creates their user, ready to claim at first sign-in" do
    assert_difference "User.count", 1 do
      post group_memberships_path(@group), params: { email: "Kim@Example.com" }
    end

    assert_equal "Added kim@example.com.", flash[:notice]
    assert_includes @group.users.reload, User.find_by!(email: "kim@example.com")
  end

  test "adding an existing member is refused" do
    post group_memberships_path(@group), params: { email: @user.email }

    assert_redirected_to group_path(@group)
    assert_equal "Couldn't add #{@user.email}: User is already a member.", flash[:alert]
  end

  test "adding an invalid email is refused" do
    assert_no_difference "User.count" do
      post group_memberships_path(@group), params: { email: "nonsense" }
    end

    assert_equal "Couldn't add nonsense: Email is invalid.", flash[:alert]
  end

  test "removing another member" do
    sam = create(:user, display_name: "Sam")
    membership = create(:group_membership, group: @group, user: sam)

    delete group_membership_path(@group, membership)

    assert_redirected_to group_path(@group)
    assert_equal "Removed Sam.", flash[:notice]
    assert_equal [ @user ], @group.users.reload
  end

  test "leaving a group returns me to my groups, and I can no longer see it" do
    create(:group_membership, group: @group)
    mine = @group.group_memberships.find_by!(user: @user)

    delete group_membership_path(@group, mine)

    assert_redirected_to groups_path
    get group_path(@group)
    assert_response :not_found
  end

  test "the last member can't leave" do
    delete group_membership_path(@group, @group.group_memberships.sole)

    assert_redirected_to group_path(@group)
    assert_equal "A group needs at least one member.", flash[:alert]
    assert_equal [ @user ], @group.users.reload
  end

  test "a membership from another group is not found" do
    other_membership = create(:group_membership)

    delete group_membership_path(@group, other_membership)

    assert_response :not_found
  end

  test "non-members can't add or remove anyone" do
    other_group = create(:group)
    membership = create(:group_membership, group: other_group)

    post group_memberships_path(other_group), params: { email: "sneaky@example.com" }
    assert_response :not_found

    delete group_membership_path(other_group, membership)
    assert_response :not_found
    assert GroupMembership.exists?(membership.id)
  end
end
