require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  test "every page below home starts with a link back to its parent" do
    user = create(:user)
    group = create(:group, name: "The Smiths", members: [ user ])
    play_list = create(:play_list, group: group, name: "Movie night")
    movie = create(:movie, name: "Arrival")
    entry = play_list.add(movie)
    sign_in_as user

    {
      new_group_path => [ groups_path, "Home" ],
      group_path(group) => [ groups_path, "Home" ],
      new_group_play_list_path(group) => [ group_path(group), "The Smiths" ],
      group_play_list_path(group, play_list) => [ group_path(group), "The Smiths" ],
      edit_group_play_list_path(group, play_list) => [ group_play_list_path(group, play_list), "Movie night" ],
      group_play_list_history_path(group, play_list) => [ group_play_list_path(group, play_list), "Movie night" ],
      new_group_play_list_list_entry_path(group, play_list) => [ group_play_list_path(group, play_list), "Movie night" ],
      group_play_list_list_entry_path(group, play_list, entry) => [ group_play_list_path(group, play_list), "Movie night" ],
      new_group_play_list_list_entry_viewing_path(group, play_list, entry) =>
        [ group_play_list_list_entry_path(group, play_list, entry), "Arrival" ],
      new_group_play_list_list_entry_cancellation_path(group, play_list, entry) =>
        [ group_play_list_list_entry_path(group, play_list, entry), "Arrival" ],
      titles_path => [ root_path, "Home" ],
      title_path(movie) => [ titles_path, "Titles" ],
      new_title_path => [ titles_path, "Titles" ]
    }.each do |page, (parent, label)|
      get page

      back = css_select("main > p.small:first-of-type a").first
      assert back, "#{page} has no back link"
      assert_equal [ parent, "← #{label}" ], [ back["href"], back.text ], "back link on #{page}"
    end
  end
end
