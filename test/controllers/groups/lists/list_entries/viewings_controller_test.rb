require "test_helper"

class Groups::Lists::ListEntries::ViewingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @group = create(:group, members: [ @user ])
    @list = create(:list, group: @group, name: "Movie night")
    @season = create(:season, name: "The Bear", season: 3, episode_count: 3)
    @entry = @list.add(@season)
    sign_in_as @user
  end

  test "an active entry's details offer a Mark as watched button" do
    get group_list_list_entry_path(@group, @list, @entry)

    assert_select "turbo-frame#watch a[href=?]", new_group_list_list_entry_viewing_path(@group, @list, @entry),
      text: "Mark as watched…"
  end

  test "the watch form defaults to the next unwatched episode and today" do
    record @season.episodes.first, on: "2026-10-01"

    travel_to Date.new(2026, 10, 14) do
      get new_group_list_list_entry_viewing_path(@group, @list, @entry)
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

    get new_group_list_list_entry_viewing_path(@group, @list, entry)

    assert_select "select", count: 0
    assert_select "input[type=hidden][name=?][value=?]", "viewing[episode_id]", movie.episodes.first.id.to_s
  end

  test "recording a mid-season watch advances the season" do
    record @season.episodes.first, on: "2026-10-12"

    assert_redirected_to group_list_path(@group, @list)
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

  test "watching a movie checks it off on the group's other lists too" do
    movie = create(:movie, name: "Arrival")
    entry = @list.add(movie)
    other = create(:list, group: @group, name: "Anime").add(movie)

    post group_list_list_entry_viewings_path(@group, @list, entry),
      params: { viewing: { episode_id: movie.episodes.first.id, date: "2026-10-14" } }

    assert_equal "Watched Arrival. Also recorded on Anime.", flash[:notice]
    assert other.reload.watched?
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

    get new_group_list_list_entry_viewing_path(@group, @list, @entry)

    assert_response :not_found
  end

  test "another group's entry can't be watched" do
    others = create(:list)
    entry = others.add(create(:movie))

    post group_list_list_entry_viewings_path(others.group, others, entry),
      params: { viewing: { episode_id: entry.title.episodes.first.id, date: "2026-10-14" } }

    assert_response :not_found
    assert entry.reload.not_started?
  end

  private
    def record(episode, on: "2026-10-14")
      post group_list_list_entry_viewings_path(@group, @list, @entry),
        params: { viewing: { episode_id: episode.id, date: on } }
    end
end
