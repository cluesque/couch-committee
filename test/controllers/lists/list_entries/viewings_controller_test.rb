require "test_helper"

class Lists::ListEntries::ViewingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @list = create(:list, members: [ @user ], name: "Movie night")
    @season = create(:season, name: "The Bear", season: 3, episode_count: 3)
    @entry = @list.add(@season)
    sign_in_as @user
  end

  test "an active entry's details offer a Mark as watched button" do
    get list_list_entry_path(@list, @entry)

    assert_select "turbo-frame#watch a[href=?]", new_list_list_entry_viewing_path(@list, @entry),
      text: "Mark as watched…"
  end

  test "the watch form defaults to the next unwatched episode and today" do
    record @season.episodes.first, on: "2026-10-01"

    travel_to Date.new(2026, 10, 14) do
      get new_list_list_entry_viewing_path(@list, @entry)
    end

    assert_response :success
    assert_select "turbo-frame#watch form[data-turbo-frame=_top]"
    assert_select "select[name=?] option[selected]", "viewing[episode_id]", text: @season.episodes.second.label
    assert_select "select[name=?] option", "viewing[episode_id]", text: "#{@season.episodes.first.label} (watched)"
    assert_select "input[name=?][value=?]", "viewing[date]", "2026-10-14"
  end

  test "a movie's watch form needs no episode picker" do
    movie = create(:movie)
    entry = @list.add(movie)

    get new_list_list_entry_viewing_path(@list, entry)

    assert_select "select", count: 0
    assert_select "input[type=hidden][name=?][value=?]", "viewing[episode_id]", movie.episodes.first.id.to_s
  end

  test "recording a mid-season watch advances the season" do
    record @season.episodes.first, on: "2026-10-12"

    assert_redirected_to list_path(@list)
    assert_equal "Watched #{@season.episodes.first.full_name}.", flash[:notice]
    assert @entry.reload.in_progress?
    assert_equal [ Date.new(2026, 10, 12) ], @entry.viewings.map(&:date)
  end

  test "recording the last episode finishes the season and takes it off the list" do
    record @season.episodes.first
    record @season.episodes.second
    record @season.episodes.third

    assert_equal "Watched #{@season.episodes.third.full_name}. Finished The Bear: Season 3.", flash[:notice]
    follow_redirect!
    assert_select "li", text: /The Bear/, count: 0
  end

  test "watching a movie leaves its other lists alone" do
    movie = create(:movie, name: "Arrival")
    entry = @list.add(movie)
    other = create(:list, members: [ @user ], name: "Anime").add(movie)

    post list_list_entry_viewings_path(@list, entry),
      params: { viewing: { episode_id: movie.episodes.first.id, date: "2026-10-14" } }

    assert_equal "Watched Arrival.", flash[:notice]
    assert entry.reload.watched?
    assert other.reload.not_started?
  end

  test "a missing date shows the form again" do
    assert_no_difference "Viewing.count" do
      record @season.episodes.first, on: ""
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger li", "Date can't be blank"
  end

  test "an episode from another title is not found" do
    record create(:movie).episodes.first

    assert_response :not_found
    assert_equal 0, Viewing.count
  end

  test "a finished entry can't be watched again from here" do
    @entry.update!(state: :watched)

    get new_list_list_entry_viewing_path(@list, @entry)

    assert_response :not_found
  end

  test "someone else's entry can't be watched" do
    others = create(:list)
    entry = others.add(create(:movie))

    post list_list_entry_viewings_path(others, entry),
      params: { viewing: { episode_id: entry.title.episodes.first.id, date: "2026-10-14" } }

    assert_response :not_found
    assert entry.reload.not_started?
  end

  private
    def record(episode, on: "2026-10-14")
      post list_list_entry_viewings_path(@list, @entry),
        params: { viewing: { episode_id: episode.id, date: on } }
    end
end
