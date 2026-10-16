require "application_system_test_case"

class RewatchingTest < ApplicationSystemTestCase
  test "watching a movie, then putting it back on for a rewatch" do
    travel_to Date.new(2026, 10, 15)
    pat = create(:user)
    group = create(:group, members: [ pat ])
    list = create(:list, group: group, name: "Movie night")
    list.add(create(:movie, name: "Arrival"))
    sign_in_as pat

    visit group_list_path(group, list)
    click_on "Arrival"
    click_on "Watch"
    within("turbo-frame#watch") do
      fill_in "Watched on", with: Date.new(2026, 10, 1)
      click_on "Record watch"
    end
    assert_text "Nothing on this list yet."

    click_on "History"
    click_link "Arrival"
    click_on "Watch again"

    assert_text "Added Arrival again."
    within("ol") { assert_link "Arrival" }
    assert_no_text "Last watched"

    click_on "History"
    within "ol" do
      assert_selector "li", count: 1
      assert_text "Arrival"
      assert_text "Oct 01"
    end
  ensure
    travel_back
  end
end
