require "application_system_test_case"

class HistoryTest < ApplicationSystemTestCase
  test "cancelling with a note, finishing a movie, and finding both in the history" do
    pat = create(:user)
    group = create(:group, members: [ pat ])
    list = create(:list, group: group, name: "Movie night")
    list.add(create(:movie, name: "Saw It"))
    list.add(create(:movie, name: "Arrival"))
    sign_in_as pat

    visit group_list_path(group, list)
    click_on "Saw It"
    click_on "Remove from list…"
    within "turbo-frame#cancellation" do
      fill_in "Why? (optional)", with: "Too scary for a weeknight."
      click_on "Remove it"
    end
    assert_text "Removed Saw It from Movie night."
    assert_no_link "Saw It"

    click_on "Arrival"
    click_on "Watch"
    within("turbo-frame#watch") { click_on "Record watch" }
    assert_text "Watched Arrival."

    click_on "History"
    within "ol" do
      assert_text "Saw It"
      assert_text "Too scary for a weeknight."
      assert_text "Arrival"
    end

    click_on "Saw It"
    assert_text "Cancelled"
    assert_text "Too scary for a weeknight."
    assert_no_link "Watch"
  end
end
