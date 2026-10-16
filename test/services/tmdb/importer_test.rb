require "test_helper"

# Runs against FakeTmdb's recorded responses: Arrival (329865) and The Bear (136315).
class Tmdb::ImporterTest < ActiveSupport::TestCase
  setup do
    @importer = Tmdb::Importer.new(client: Tmdb::Client.new(token: "test-token"))
  end

  test "importing a movie creates its title and its one episode" do
    travel_to Time.zone.local(2026, 10, 16, 12) do
      arrival = @importer.import_movie(329865)

      assert arrival.persisted?
      assert arrival.movie?
      assert_equal [ 329865, "Arrival", "tt2543164", 116 ], arrival.values_at(:tmdb_id, :name, :imdb_id, :runtime_minutes)
      assert_equal "Drama, Science Fiction, Mystery", arrival.genres
      assert arrival.overview.present?
      assert arrival.poster_path.start_with?("/")
      assert arrival.backdrop_path.start_with?("/")
      assert_equal Time.zone.local(2026, 10, 16, 12), arrival.tmdb_synced_at
      assert_equal [ [ 1, Date.new(2016, 11, 10), 116 ] ],
        arrival.episodes.map { |episode| [ episode.number, episode.available_on, episode.runtime_minutes ] }
    end
  end

  test "a movie's rating is its first non-blank US certification" do
    assert_equal "PG-13", @importer.import_movie(329865).rating
  end

  test "importing a season creates its title and episodes" do
    season = @importer.import_season(136315, 1)

    assert season.series?
    assert_equal [ 136315, 1, "The Bear", "The Bear: Season 1" ], [ season.tmdb_id, season.season, season.name, season.full_name ]
    assert_equal [ "Hulu", "TV-MA", "tt14452776" ], season.values_at(:network, :rating, :imdb_id)
    assert_nil season.runtime_minutes
    assert_equal (1..8).to_a, season.episodes.map(&:number)

    first = season.episodes.first
    assert_equal [ "System", Date.new(2022, 6, 23), 28 ], [ first.name, first.available_on, first.runtime_minutes ]
    assert first.overview.present?
    assert first.still_path.start_with?("/")
  end

  test "a season without an overview of its own takes the show's" do
    season = @importer.import_season(136315, 1)

    show_overview = JSON.parse(FakeTmdb::FIXTURES.join("tv-136315.json").read)["overview"]
    assert_equal show_overview, season.overview
  end

  test "each season of a show is its own title" do
    first = @importer.import_season(136315, 1)
    second = @importer.import_season(136315, 2)

    assert_not_equal first, second
    assert_equal [ 1, 2 ], Title.where(tmdb_id: 136315).order(:season).pluck(:season)
  end

  test "importing again refreshes the existing title instead of duplicating it" do
    arrival = @importer.import_movie(329865)
    arrival.update!(name: "Wrong name")
    arrival.episodes.first.update!(available_on: Date.new(2000, 1, 1))

    assert_no_difference [ "Title.count", "Episode.count" ] do
      assert_equal arrival, @importer.import_movie(329865)
    end
    arrival.reload
    assert_equal "Arrival", arrival.name
    assert_equal Date.new(2016, 11, 10), arrival.episodes.first.available_on
  end

  test "a refresh drops episodes TMDB no longer lists, unless they've been watched" do
    season = @importer.import_season(136315, 1)
    gone = create(:episode, title: season, number: 9)
    watched = create(:episode, title: season, number: 10)
    list = create(:list)
    list.add(season)
    WatchRecorder.call(group: list.group, episode: watched, date: Date.new(2026, 10, 1))
    assert_equal 1, watched.viewings.count

    @importer.import_season(136315, 1)

    assert_not Episode.exists?(gone.id)
    assert Episode.exists?(watched.id)
    assert_equal (1..8).to_a + [ 10 ], season.reload.episodes.map(&:number)
  end

  test "importing into a hand-entered movie links it, keeping its episode and viewings" do
    movie = create(:movie, name: "arrival", tmdb_id: nil)
    episode = movie.episodes.sole
    list = create(:list)
    list.add(movie)
    WatchRecorder.call(group: list.group, episode: episode, date: Date.new(2026, 9, 1))

    assert_no_difference [ "Title.count", "Episode.count", "Viewing.count" ] do
      assert_equal movie, @importer.import_movie(329865, into: movie)
    end
    movie.reload
    assert_equal [ 329865, "Arrival", "PG-13" ], movie.values_at(:tmdb_id, :name, :rating)
    assert_equal episode, movie.episodes.sole
    assert_equal Date.new(2016, 11, 10), episode.reload.available_on
    assert_equal 1, episode.viewings.count
  end

  test "importing into a hand-entered season matches its episodes by number" do
    season = create(:season, name: "Bear", season: 1, episode_count: 0, tmdb_id: nil)
    watched = create(:episode, title: season, number: 2, name: "Ep two")
    unwatched_extra = create(:episode, title: season, number: 12)
    list = create(:list)
    list.add(season)
    WatchRecorder.call(group: list.group, episode: watched, date: Date.new(2026, 9, 1))

    @importer.import_season(136315, 1, into: season)

    season.reload
    assert_equal [ 136315, 1, "The Bear" ], season.values_at(:tmdb_id, :season, :name)
    assert_equal (1..8).to_a, season.episodes.map(&:number)
    assert_equal "Hands", watched.reload.name
    assert_equal 1, watched.viewings.count
    assert_not Episode.exists?(unwatched_extra.id)
  end

  test "refresh re-imports a linked title, filling in episodes TMDB has added since" do
    season = @importer.import_season(136315, 1)
    season.episodes.where(number: 3..).destroy_all
    season.episodes.first.update!(available_on: nil)

    @importer.refresh(season.reload)

    assert_equal (1..8).to_a, season.reload.episodes.map(&:number)
    assert_equal Date.new(2022, 6, 23), season.episodes.first.available_on
  end

  test "a failed import creates nothing" do
    assert_no_difference "Title.count" do
      assert_raises(Tmdb::Error) { @importer.import_season(136315, 99) }
    end
  end
end
