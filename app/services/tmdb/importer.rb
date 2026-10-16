module Tmdb
  # Brings a TMDB movie, or one season of a TMDB show, into the catalog as a Title with its
  # Episodes. Importing something already in the catalog refreshes it in place.
  class Importer
    def initialize(client: Client.new)
      @client = client
    end

    def import_movie(tmdb_id)
      movie = @client.movie(tmdb_id)
      title = Title.find_or_initialize_by(kind: :movie, tmdb_id: tmdb_id)

      title.assign_attributes(
        name: movie["title"],
        overview: movie["overview"].presence,
        poster_path: movie["poster_path"],
        backdrop_path: movie["backdrop_path"],
        genres: genre_names(movie),
        runtime_minutes: movie["runtime"].presence&.nonzero?,
        rating: us_movie_certification(movie),
        imdb_id: movie["imdb_id"].presence,
        tmdb_synced_at: Time.current
      )
      episode_numbered(title, 1).assign_attributes(available_on: movie["release_date"].presence,
        runtime_minutes: title.runtime_minutes)

      title.save!
      title
    end

    # A season with no overview or poster of its own takes the show's.
    def import_season(tmdb_show_id, season_number)
      show = @client.tv(tmdb_show_id)
      season = @client.season(tmdb_show_id, season_number)
      title = Title.find_or_initialize_by(kind: :series, tmdb_id: tmdb_show_id, season: season_number)

      title.assign_attributes(
        name: show["name"],
        overview: season["overview"].presence || show["overview"].presence,
        poster_path: season["poster_path"] || show["poster_path"],
        backdrop_path: show["backdrop_path"],
        genres: genre_names(show),
        rating: show.dig("content_ratings", "results")&.find { |rating| rating["iso_3166_1"] == "US" }&.dig("rating").presence,
        network: show["networks"]&.first&.dig("name"),
        imdb_id: show.dig("external_ids", "imdb_id").presence,
        tmdb_synced_at: Time.current
      )
      sync_episodes(title, season["episodes"])

      title.save!
      title
    end

    private
      def episode_numbered(title, number)
        title.episodes.find { |episode| episode.number == number } || title.episodes.build(number: number)
      end

      # Episodes TMDB no longer lists are dropped, unless someone has already watched them.
      def sync_episodes(title, episodes)
        episodes.each do |data|
          episode_numbered(title, data["episode_number"]).assign_attributes(
            name: data["name"].presence,
            available_on: data["air_date"].presence,
            overview: data["overview"].presence,
            still_path: data["still_path"],
            runtime_minutes: data["runtime"].presence&.nonzero?
          )
        end

        listed = episodes.map { |data| data["episode_number"] }
        title.episodes.each do |episode|
          episode.mark_for_destruction if episode.persisted? && !episode.number.in?(listed) && episode.viewings.none?
        end
      end

      def genre_names(data)
        data["genres"]&.map { |genre| genre["name"] }&.join(", ").presence
      end

      # TMDB often lists a premiere release with a blank certification ahead of the rated one.
      def us_movie_certification(movie)
        us = movie.dig("release_dates", "results")&.find { |country| country["iso_3166_1"] == "US" }
        us&.dig("release_dates")&.map { |release| release["certification"] }&.find(&:present?)
      end
  end
end
