require "application_system_test_case"

class HistoryTest < ApplicationSystemTestCase
  test "cancelling with a note, finishing a movie, and finding both in the history" do
    pat = create(:user)
    group = create(:group, members: [ pat ])
    play_list = create(:play_list, group: group, name: "Movie night")
    play_list.add(create(:movie, name: "Saw It"))
    play_list.add(create(:movie, name: "Arrival"))
    sign_in_as pat

    visit group_play_list_path(group, play_list)
    click_on "Saw It"
    click_on "Cancel…"
    within "turbo-frame#cancellation" do
      fill_in "Why? (optional)", with: "Too scary for a weeknight."
      click_on "Cancel it"
    end
    assert_text "Cancelled Saw It."
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
