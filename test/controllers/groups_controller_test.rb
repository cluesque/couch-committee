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
    assert_equal [ "Alpha", "Zeta" ], section_items("Groups")
  end

  test "the home page shows my lists, then my groups, under the logo banner" do
    group = create(:group, name: "The Smiths", members: [ @user ])
    create(:list, group: group, name: "Movie night")

    get root_path

    assert_response :success
    assert_select "img[src=?]", "/logo_with_name.png"
    assert_equal [ "Lists", "Groups" ], css_select("h2").map(&:text)
    assert_equal [ "Movie night" ], section_items("Lists")
    assert_equal [ "The Smiths" ], section_items("Groups")
  end

  test "home lists the lists of all my groups, alphabetically, linking to each" do
    smiths = create(:group, name: "The Smiths", members: [ @user ])
    book_club = create(:group, name: "Book club", members: [ @user ])
    movie_night = create(:list, group: smiths, name: "Movie night")
    create(:list, group: book_club, name: "Audiobooks")
    create(:list, name: "Someone else's")

    get root_path

    assert_equal [ "Audiobooks Book club", "Movie night The Smiths" ], section_items("Lists")
    assert_select "a[href=?]", group_list_path(smiths, movie_night)
  end

  test "with a single group, home doesn't repeat its name on every list" do
    group = create(:group, name: "The Smiths", members: [ @user ])
    create(:list, group: group, name: "Movie night")

    get root_path

    assert_equal [ "Movie night" ], section_items("Lists")
  end

  test "home suggests starting a list when my groups have none" do
    create(:group, members: [ @user ])

    get root_path

    assert_select "p", "No lists yet. Open a group below to start one."
  end

  test "home has no lists section before I'm in any group" do
    get root_path

    assert_equal [ "Groups" ], css_select("h2").map(&:text)
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

  private
    # The link texts of the list-group that follows the heading with the given text.
    def section_items(heading)
      heading_node = css_select("h2").find { |node| node.text == heading }
      list = heading_node.xpath("following::div[contains(@class, 'list-group')][1]").first
      list.css("a").map { |item| item.text.squish }
    end
end
