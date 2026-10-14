require "test_helper"

class GroupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as @user
  end

  test "lists only my groups, alphabetically" do
    create(:group, name: "Zeta", members: [ @user ])
    create(:group, name: "Alpha", members: [ @user ])
    create(:group, name: "Someone else's")

    get groups_path

    assert_response :success
    assert_equal [ "Alpha", "Zeta" ], css_select(".list-group-item").map { |item| item.text.strip }
  end

  test "the home page is my list of groups, under the logo banner" do
    get root_path

    assert_response :success
    assert_select "img[src=?]", "/logo_with_name.png"
    assert_select "h1", "Your groups"
  end

  test "explains what to do when I'm in no groups" do
    get groups_path

    assert_select "p", text: /not in any groups yet.*#{Regexp.escape(@user.email)}/m
  end

  test "new group form" do
    get new_group_path

    assert_response :success
    assert_select "form input[name=?]", "group[name]"
  end

  test "creating a group makes me its first member" do
    assert_difference [ "Group.count", "GroupMembership.count" ], 1 do
      post groups_path, params: { group: { name: "The Smiths" } }
    end

    group = Group.last
    assert_redirected_to group_path(group)
    assert_equal [ @user ], group.users
  end

  test "a group needs a name" do
    assert_no_difference "Group.count" do
      post groups_path, params: { group: { name: " " } }
    end

    assert_response :unprocessable_content
    assert_select ".invalid-feedback", "Name can't be blank"
  end

  test "a group's page lists its members" do
    sam = create(:user, display_name: "Sam")
    invited = create(:user, :invited, email: "kim@example.com")
    group = create(:group, name: "The Smiths", members: [ @user, sam, invited ])

    get group_path(group)

    assert_response :success
    assert_select "h1", "The Smiths"
    assert_select "li", text: /Sam/
    assert_select "li", text: /kim@example.com/
  end

  test "a group's page is not found for non-members" do
    get group_path(create(:group))

    assert_response :not_found
  end
end
