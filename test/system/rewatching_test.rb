require "application_system_test_case"

class RewatchingTest < ApplicationSystemTestCase
  test "watching a movie, then putting it back on for a rewatch" do
    travel_to Date.new(2026, 10, 15)
    pat = create(:user)
    list = create(:list, members: [ pat ], name: "Movie night")
    list.add(create(:movie, name: "Arrival"))
    sign_in_as pat

    visit list_path(list)
    click_on "Arrival"
    click_on "Mark as watched…"
    within("turbo-frame#watch") do
      fill_in "Watched on", with: Date.new(2026, 10, 1)
      click_on "Mark watched"
    end
    assert_text "All caught up."

    click_on "History"
    click_link "Arrival"
    click_on "Add to list again"

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
