require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  test "every page below home starts with a link back to its parent" do
    user = create(:user)
    list = create(:list, members: [ user ], name: "Movie night")
    movie = create(:movie, name: "Arrival")
    entry = list.add(movie)
    sign_in_as user

    {
      new_list_path => [ root_path, "Home" ],
      list_path(list) => [ root_path, "Home" ],
      edit_list_path(list) => [ list_path(list), "Movie night" ],
      list_history_path(list) => [ list_path(list), "Movie night" ],
      new_list_list_entry_path(list) => [ list_path(list), "Movie night" ],
      list_list_entry_path(list, entry) => [ list_path(list), "Movie night" ],
      new_list_list_entry_viewing_path(list, entry) =>
        [ list_list_entry_path(list, entry), "Arrival" ],
      new_list_list_entry_cancellation_path(list, entry) =>
        [ list_list_entry_path(list, entry), "Arrival" ],
      titles_path => [ root_path, "Home" ],
      title_path(movie) => [ titles_path, "Titles" ]
    }.each do |page, (parent, label)|
      get page

      back = css_select("main > p.small:first-of-type a").first
      assert back, "#{page} has no back link"
      assert_equal [ parent, "← #{label}" ], [ back["href"], back.text ], "back link on #{page}"
    end
  end
end
