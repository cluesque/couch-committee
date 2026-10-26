require "test_helper"

class ListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as @user
  end

  test "home shows the lists I'm on, alphabetically, under the logo banner" do
    movie_night = create(:list, members: [ @user ], name: "Movie night")
    create(:list, members: [ @user ], name: "Anime")
    create(:list, name: "Someone else's")

    get root_path

    assert_response :success
    assert_select "img[src=?]", "/logo_with_name.png"
    assert_equal [ "Anime", "Movie night" ], css_select(".list-group a > div:first-child").map(&:text)
    assert_select "a[href=?]", list_path(movie_night)
    assert_select "a[href=?]", new_list_path, text: "New list"
  end

  test "home says who else is on each list" do
    sam = create(:user, display_name: "Sam")
    alex = create(:user, display_name: "alex")
    create(:list, members: [ @user, sam, alex ], name: "Movie night").add(create(:movie))
    create(:list, members: [ @user ], name: "Solo").add(create(:movie))

    get root_path

    assert_equal [ "Movie night with alex and Sam", "Solo" ], css_select(".list-group a").map { |link| link.text.squish }
  end

  test "home points out New list while none of my lists is shared, and marks empty lists" do
    create(:list, members: [ @user ], name: List::JUST_ME)
    create(:list, members: [ @user ], name: "Watched it all").add(create(:movie)).update!(state: :watched)

    get root_path

    assert_select ".hint", text: /Watching with someone\? Start a list for the two of you\./
    assert_equal [ "Just Me Empty. Open it to add something you want to watch.", "Watched it all" ],
      css_select(".list-group a").map { |link| link.text.squish }
  end

  test "once a list is shared, home stops pointing out New list" do
    create(:list, members: [ @user ], name: List::JUST_ME)
    create(:list, members: [ @user, create(:user) ], name: "Movie night")

    get root_path

    assert_select ".hint", count: 0
  end

  test "an empty list points up at Add a title, and suggests sharing it" do
    list = create(:list, members: [ @user ], name: "Movie night")

    get list_path(list)

    assert_select ".hint", text: /Start here: find a movie or show to put on the list\./
    assert_select "p", text: /Just you so far\. Add people from Edit to watch together\./
    assert_select "p a[href=?]", edit_list_path(list), text: "Edit"
  end

  test "an empty Just Me or shared list doesn't suggest sharing" do
    just_me = create(:list, members: [ @user ], name: List::JUST_ME)
    shared = create(:list, members: [ @user, create(:user) ])

    [ just_me, shared ].each do |list|
      get list_path(list)
      assert_select "p", text: /Just you so far/, count: 0
    end
  end

  test "a list with everything watched says it's all caught up" do
    list = create(:list, members: [ @user ])
    list.add(create(:movie)).update!(state: :watched)

    get list_path(list)

    assert_select ".hint", text: /All caught up\. Find the next movie or show to put on the list\./
  end

  test "home explains what to do when I'm on no lists" do
    get root_path

    assert_select "p", text: /not on any lists yet.*#{Regexp.escape(@user.email)}/m
  end

  test "creating a list makes me its only member" do
    get new_list_path
    assert_response :success

    assert_difference [ "List.count", "ListMembership.count" ], 1 do
      post lists_path, params: { list: { name: "Movie night", description: "Fridays" } }
    end

    list = List.last
    assert_redirected_to list_path(list)
    assert_equal [ "Movie night", "Fridays" ], [ list.name, list.description ]
    assert_equal [ @user ], list.users
  end

  test "a list needs a name" do
    post lists_path, params: { list: { name: "" } }

    assert_response :unprocessable_content
    assert_select ".invalid-feedback", "Name can't be blank"
  end

  test "a list's page shows its name and description" do
    list = create(:list, members: [ @user ], name: "Movie night", description: "Fridays")

    get list_path(list)

    assert_response :success
    assert_select "h1", "Movie night"
    assert_select "p", "Fridays"
  end

  test "the default view shows active entries in order with what's next" do
    travel_to Date.new(2026, 10, 14) do
      list = create(:list, members: [ @user ])
      season = create(:season, name: "The Bear", season: 3, episode_count: 0)
      first = create(:episode, title: season, number: 1, name: "Tomorrow", available_on: Date.new(2026, 6, 26))
      create(:episode, title: season, number: 2, name: "Next", available_on: Date.new(2026, 6, 26))
      upcoming = create(:movie, name: "Sequel")
      upcoming.episodes.first.update!(available_on: Date.new(2026, 12, 25))

      entry = list.add(season)
      list.add(upcoming)
      list.add(create(:movie, name: "Done")).update!(state: :watched)
      create(:viewing, list_entry: entry, episode: first, date: Date.new(2026, 10, 12))

      get list_path(list)

      rows = css_select("ol > li")
      assert_equal [ "The Bear: Season 3", "Sequel" ], rows.map { |row| row.at_css(".fw-medium").text }
      assert_equal "Next: 2. Next Last watched Oct 12", rows.first.at_css(".small").text.squish
      assert_nil rows.first.at_css(".badge")
      assert_equal "Coming Dec 25", rows[1].at_css(".badge").text.squish
      assert_includes rows[1]["class"], "text-body-secondary"
      assert_equal [ "Series", "Movie" ], rows.map { |row| row.at_css("svg.kind-icon")["aria-label"] }
    end
  end

  test "the list can show just its movies, or just its series" do
    list = create(:list, members: [ @user ], name: "Movie night")
    list.add(create(:movie, name: "Arrival"))
    list.add(create(:season, name: "The Bear"))
    list.add(create(:movie, name: "Heat"))

    get list_path(list)
    assert_equal [ "Arrival", "The Bear", "Heat" ], css_select("ol > li .fw-medium").map(&:text)
    assert_select ".dropdown-toggle", text: /Showing: Movies and series/
    assert_equal [ "Movies and series 3", "Movies 2", "Series 1" ], css_select("main .dropdown-item").map { |item| item.text.squish }
    assert_select ".dropdown-item.active[href=?]", list_path(list)

    get list_path(list, kind: "movie")
    assert_equal [ "Arrival", "Heat" ], css_select("ol > li .fw-medium").map(&:text)
    assert_select ".dropdown-toggle", text: /Showing: Movies/
    assert_select ".dropdown-item.active[href=?]", list_path(list, kind: "movie")

    get list_path(list, kind: "series")
    assert_equal [ "The Bear" ], css_select("ol > li .fw-medium").map(&:text)
  end

  test "a filter with nothing in it says so" do
    list = create(:list, members: [ @user ])
    list.add(create(:movie))

    get list_path(list, kind: "series")

    assert_select "p", "No series on this list right now."
  end

  test "an unknown filter shows everything" do
    list = create(:list, members: [ @user ])
    list.add(create(:movie))
    list.add(create(:season))

    get list_path(list, kind: "opera")

    assert_select "ol > li", count: 2
  end

  test "an empty list has no filter" do
    get list_path(create(:list, members: [ @user ]))

    assert_select ".dropdown-toggle", count: 0
  end

  test "editing a list" do
    list = create(:list, members: [ @user ], name: "Movie night")

    get edit_list_path(list)
    assert_response :success

    patch list_path(list), params: { list: { name: "Film club", description: "" } }

    assert_redirected_to list_path(list)
    assert_equal "Film club", list.reload.name
  end

  test "editing keeps the name required" do
    list = create(:list, members: [ @user ])

    patch list_path(list), params: { list: { name: "" } }

    assert_response :unprocessable_content
  end

  test "a list's edit page shows who's on it, with a way to add someone" do
    sam = create(:user, display_name: "Sam")
    invited = create(:user, :invited, email: "kim@example.com")
    list = create(:list, members: [ @user, sam, invited ])

    get edit_list_path(list)

    assert_select "li", text: /Sam/
    assert_select "li", text: /kim@example.com.*Hasn't signed in yet|Hasn't signed in yet.*kim@example.com/m
    assert_select "form[action=?] input[name=email]", list_memberships_path(list)
  end

  test "the edit page offers to delete the list, naming who else loses it" do
    list = create(:list, name: "Movie night",
      members: [ @user, create(:user, display_name: "Sam"), create(:user, display_name: "alex") ])

    get edit_list_path(list)

    assert_select "form[action=?][data-turbo-confirm=?] button", list_path(list),
      "Delete Movie night for you, alex and Sam?", text: "Delete list"
  end

  test "deleting a list I'm alone on just asks about the list" do
    list = create(:list, name: "Just Me", members: [ @user ])

    get edit_list_path(list)

    assert_select "form[data-turbo-confirm=?]", "Delete Just Me?"
  end

  test "deleting a list hides it and offers to undo" do
    list = create(:list, name: "Movie night", members: [ @user ])

    delete list_path(list)

    assert_redirected_to root_path
    assert list.reload.deleted_at?
    follow_redirect!
    assert_select ".alert", text: /Deleted Movie night\./
    assert_select ".alert form[action=?] button", list_restoration_path(list), text: "Undo"
    assert_select ".list-group a", text: "Movie night", count: 0

    get list_path(list)
    assert_response :not_found
  end

  test "undo brings a deleted list back" do
    list = create(:list, name: "Movie night", members: [ @user ])
    list.soft_delete

    post list_restoration_path(list)

    assert_redirected_to list_path(list)
    assert_equal "Restored Movie night.", flash[:notice]
    assert_nil list.reload.deleted_at
  end

  test "only a deleted list I was on can be restored" do
    others = create(:list)
    others.soft_delete
    mine = create(:list, members: [ @user ])

    post list_restoration_path(others)
    assert_response :not_found
    assert others.reload.deleted_at?

    post list_restoration_path(mine)
    assert_response :not_found
  end

  test "someone else's list can't be deleted" do
    others = create(:list)

    delete list_path(others)

    assert_response :not_found
    assert_nil others.reload.deleted_at
  end

  test "list rows show each entry's tags" do
    list = create(:list, members: [ @user ])
    entry = list.add(create(:movie, name: "Arrival"))
    entry.tags << create(:tag, list: list, name: "Alice+", color: "purple")

    get list_path(list)

    assert_select "li##{ActionView::RecordIdentifier.dom_id(entry)} .tag.tag-purple", "Alice+"
  end

  test "the Showing menu filters by tag, with counts" do
    list = create(:list, members: [ @user ])
    alice = create(:tag, list: list, name: "Alice+")
    create(:tag, list: list, name: "Cozy")
    list.add(create(:movie, name: "Arrival")).tags << alice
    list.add(create(:movie, name: "Saw It"))

    get list_path(list, tag: alice.id)

    assert_equal [ "Arrival" ], css_select("ol > li .fw-medium").map(&:text)
    assert_select "button.dropdown-toggle .tag", "Alice+"
    assert_equal [ [ "Alice+", "1" ], [ "Cozy", "0" ] ],
      css_select(".dropdown-menu a .tag").map { |pill| [ pill.text, pill.next_element.text ] }
    assert_select ".dropdown-menu a.active", count: 1
    assert_select ".dropdown-menu a.active .tag", "Alice+"
  end

  test "filtering by a tag nothing has says so" do
    list = create(:list, members: [ @user ])
    cozy = create(:tag, list: list, name: "Cozy")
    list.add(create(:movie))

    get list_path(list, tag: cozy.id)

    assert_select "p", text: /Nothing tagged\s+Cozy\s+right now/
  end

  test "another list's tag doesn't filter" do
    list = create(:list, members: [ @user ])
    list.add(create(:movie, name: "Arrival"))

    get list_path(list, tag: create(:tag).id)

    assert_equal [ "Arrival" ], css_select("ol > li .fw-medium").map(&:text)
  end

  test "a rewatch starts without the earlier entry's tags" do
    list = create(:list, members: [ @user ])
    movie = create(:movie)
    earlier = list.add(movie)
    earlier.tags << create(:tag, list: list)
    earlier.update!(state: :watched)

    post list_list_entries_path(list), params: { title_id: movie.id }

    assert_empty list.list_entries.active.sole.tags
  end

  test "someone else's lists are not found" do
    others = create(:list)

    get list_path(others)
    assert_response :not_found

    get edit_list_path(others)
    assert_response :not_found

    patch list_path(others), params: { list: { name: "Mine now" } }
    assert_response :not_found
  end
end
