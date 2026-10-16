class AddTmdbMetadataToTitlesAndEpisodes < ActiveRecord::Migration[8.1]
  def change
    change_table :titles, bulk: true do |t|
      t.integer :tmdb_id
      t.string :imdb_id
      t.text :overview
      t.string :poster_path
      t.string :backdrop_path
      t.string :genres
      t.integer :runtime_minutes
      t.string :rating
      t.string :network
      t.datetime :tmdb_synced_at
    end

    # One Title per TMDB movie, and per (TMDB show, season). These are two partial indexes rather
    # than one on (kind, tmdb_id, season), because a movie's season is NULL and SQLite (like
    # Postgres by default) treats NULLs as distinct, which would let a movie be imported twice.
    add_index :titles, :tmdb_id, unique: true, where: "kind = 0 AND tmdb_id IS NOT NULL",
      name: "index_titles_on_tmdb_movie"
    add_index :titles, [ :tmdb_id, :season ], unique: true, where: "kind = 1 AND tmdb_id IS NOT NULL",
      name: "index_titles_on_tmdb_season"

    change_table :episodes, bulk: true do |t|
      t.text :overview
      t.string :still_path
      t.integer :runtime_minutes
    end
  end
end
