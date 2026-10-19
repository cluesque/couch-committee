require "application_system_test_case"

class WhereToWatchTest < ApplicationSystemTestCase
  test "an entry's page fills in where to watch" do
    pat = create(:user)
    list = create(:list, members: [ pat ])
    arrival = Tmdb::Importer.new(client: Tmdb::Client.new(token: "test")).import_movie(329865)
    entry = list.add(arrival)
    sign_in_as pat

    visit list_list_entry_path(list, entry)

    within "turbo-frame#where_to_watch" do
      assert_text "Where to watch"
      assert_text "Stream"
      assert_selector "img[alt='Kanopy']"
      assert_link "JustWatch"
    end
  end
end
