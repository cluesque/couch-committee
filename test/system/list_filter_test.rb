require "application_system_test_case"

class ListFilterTest < ApplicationSystemTestCase
  test "showing just the movies on a list" do
    pat = create(:user)
    group = create(:group, members: [ pat ])
    list = create(:list, group: group, name: "Movie night")
    list.add(create(:movie, name: "Arrival"))
    list.add(create(:season, name: "The Bear"))
    sign_in_as pat

    visit group_list_path(group, list)
    click_on "Showing: Movies and series"
    within("main .dropdown-menu") { click_link "Movies 1" }

    assert_selector ".dropdown-toggle", text: "Showing: Movies"
    within("ol") do
      assert_text "Arrival"
      assert_no_text "The Bear"
    end
  end
end
