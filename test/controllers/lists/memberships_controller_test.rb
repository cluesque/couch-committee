require "test_helper"

class Lists::MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @list = create(:list, members: [ @user ], name: "Movie night")
    sign_in_as @user
  end

  test "adding someone who already has an account" do
    sam = create(:user, email: "sam@example.com")

    post list_memberships_path(@list), params: { email: "sam@example.com" }

    assert_redirected_to edit_list_path(@list)
    assert_equal "Added sam@example.com.", flash[:notice]
    assert_includes @list.users.reload, sam
  end

  test "adding someone new creates their user, ready to claim at first sign-in" do
    assert_difference "User.count", 1 do
      post list_memberships_path(@list), params: { email: "Kim@Example.com" }
    end

    assert_equal "Added kim@example.com.", flash[:notice]
    assert_includes @list.users.reload, User.find_by!(email: "kim@example.com")
  end

  test "adding someone already on the list is refused" do
    post list_memberships_path(@list), params: { email: @user.email }

    assert_redirected_to edit_list_path(@list)
    assert_equal "Couldn't add #{@user.email}: User is already on this list.", flash[:alert]
  end

  test "adding an invalid email is refused" do
    assert_no_difference "User.count" do
      post list_memberships_path(@list), params: { email: "nonsense" }
    end

    assert_equal "Couldn't add nonsense: Email is invalid.", flash[:alert]
  end

  test "removing someone else" do
    sam = create(:user, display_name: "Sam")
    membership = create(:list_membership, list: @list, user: sam)

    delete list_membership_path(@list, membership)

    assert_redirected_to edit_list_path(@list)
    assert_equal "Removed Sam from Movie night.", flash[:notice]
    assert_equal [ @user ], @list.users.reload
  end

  test "leaving a list returns me home, and I can no longer see it" do
    create(:list_membership, list: @list)
    mine = @list.list_memberships.find_by!(user: @user)

    delete list_membership_path(@list, mine)

    assert_redirected_to root_path
    assert_equal "You left Movie night.", flash[:notice]
    get list_path(@list)
    assert_response :not_found
  end

  test "the last member can't leave" do
    delete list_membership_path(@list, @list.list_memberships.sole)

    assert_redirected_to edit_list_path(@list)
    assert_equal "A list needs at least one member.", flash[:alert]
    assert_equal [ @user ], @list.users.reload
  end

  test "a membership of another list is not found" do
    other_membership = create(:list_membership)

    delete list_membership_path(@list, other_membership)

    assert_response :not_found
  end

  test "people not on a list can't add or remove anyone" do
    other_list = create(:list)
    membership = create(:list_membership, list: other_list)

    post list_memberships_path(other_list), params: { email: "sneaky@example.com" }
    assert_response :not_found

    delete list_membership_path(other_list, membership)
    assert_response :not_found
    assert ListMembership.exists?(membership.id)
  end
end
