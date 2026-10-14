require "application_system_test_case"

class TitlesTest < ApplicationSystemTestCase
  setup do
    sign_in_as create(:user)
  end

  test "adding a movie" do
    click_on "Browse titles"
    click_on "Add a movie"
    fill_in "Name", with: "Arrival"
    fill_in "Release date", with: Date.new(2016, 11, 11)
    click_on "Add movie"

    assert_text "Added Arrival."
    assert_text "Released November 11, 2016"
  end

  test "adding a season, adding and removing episode rows as I go" do
    click_on "Browse titles"
    click_on "Add a season"
    fill_in "Series name", with: "The Bear"
    fill_in "Season number", with: "3"

    within(episode_row(1)) { fill_in "Episode name", with: "Tomorrow" }
    click_on "Add another episode"
    within(episode_row(2)) do
      assert_field "No.", with: "2"
      fill_in "Episode name", with: "Typo"
    end
    click_on "Add another episode"
    within(episode_row(3)) do
      assert_field "No.", with: "3"
      fill_in "Episode name", with: "Next"
      fill_in "Available on", with: Date.new(2026, 7, 3)
    end
    within(episode_row(2)) { click_on "Remove episode" }
    click_on "Add season"

    assert_text "Added The Bear: Season 3."
    assert_equal [ "1. Tomorrow", "3. Next Jul 03" ], all("li").map { |item| item.text.squish }
  end

  private
    def episode_row(position)
      find_all("[data-episode-fields-target~='row']", minimum: position)[position - 1]
    end
end
