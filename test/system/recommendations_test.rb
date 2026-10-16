require "application_system_test_case"

class RecommendationsTest < ApplicationSystemTestCase
  setup do
    @pat = create(:user)
    @group = create(:group, members: [ @pat ])
    @list = create(:list, group: @group, name: "Movie night")
    sign_in_as @pat
  end

  test "a recommendation typed with the search comes along through the season picker" do
    visit new_group_list_list_entry_path(@group, @list)
    fill_in "Search movies and shows", with: "the bear"
    click_on "Search"
    fill_in "Why this one? (optional)", with: "Sam says it's the best show on TV"
    click_on "Seasons of The Bear"
    assert_field "Why this one? (optional)", with: "Sam says it's the best show on TV"
    click_on "Add The Bear: Season 1"

    assert_text "Added The Bear: Season 1."
    within("ol") { assert_text "“Sam says it's the best show on TV”" }
  end

  test "pressing Enter in the recommendation field doesn't add anything" do
    visit new_group_list_list_entry_path(@group, @list, q: "arrival")
    fill_in "Why this one? (optional)", with: "Oops"
    find_field("Why this one? (optional)").send_keys(:enter)
    sleep 1 # nothing to wait *for* when the right outcome is that nothing happens

    assert_current_path new_group_list_list_entry_path(@group, @list, q: "arrival")
    assert_equal 0, @list.list_entries.count
  end

  test "editing a recommendation in place" do
    entry = @list.add(create(:movie, name: "Arrival"))
    visit group_list_list_entry_path(@group, @list, entry)

    click_on "Add a recommendation"
    within "turbo-frame#recommendation" do
      fill_in "Why it's on the list (optional)", with: "Pat loved it"
      click_on "Save"
    end

    assert_text "Saved."
    assert_selector "turbo-frame#recommendation blockquote", text: "“Pat loved it”"
  end
end
