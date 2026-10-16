module Tmdb
  # A movie or TV show found by Client#search. `kind` matches Title's: "movie" or "series".
  SearchResult = Data.define(:kind, :tmdb_id, :name, :year, :poster_path, :overview) do
    def self.from_json(result)
      movie = result["media_type"] == "movie"

      new(
        kind: movie ? "movie" : "series",
        tmdb_id: result["id"],
        name: movie ? result["title"] : result["name"],
        year: (movie ? result["release_date"] : result["first_air_date"]).to_s[0, 4].presence&.to_i,
        poster_path: result["poster_path"],
        overview: result["overview"].presence
      )
    end
  end
end
