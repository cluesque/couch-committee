module Tmdb
  # The handful of TMDB API calls the app makes. Detail methods return TMDB's parsed JSON for the
  # importer to map onto Title and Episode; failures of any kind raise Tmdb::Error.
  class Client
    def initialize(token: Rails.application.credentials.dig(:tmdb, :api_read_access_token))
      @token = token
    end

    # Movies and TV shows matching the query, most relevant first. People are left out.
    def search(query)
      get("search/multi", query: query, include_adult: false)["results"]
        .select { |result| result["media_type"].in?(%w[ movie tv ]) }
        .map { |result| SearchResult.from_json(result) }
    end

    def movie(id)
      get("movie/#{id}", append_to_response: "release_dates")
    end

    def tv(id)
      get("tv/#{id}", append_to_response: "external_ids,content_ratings")
    end

    def season(tv_id, season_number)
      get("tv/#{tv_id}/season/#{season_number}")
    end

    # Where to stream, rent, or buy, by country code. `kind` is a Title kind: "movie" or "series".
    def watch_providers(kind, id)
      get("#{kind == "series" ? "tv" : "movie"}/#{id}/watch/providers")["results"]
    end

    private
      def get(path, **params)
        response = connection.get(path, params)
        raise Error, "TMDB answered #{response.status} for #{path}" unless response.success?

        response.body
      rescue Faraday::Error => error
        raise Error, "Couldn't reach TMDB: #{error.message}"
      end

      def connection
        @connection ||= Faraday.new(url: API_URL,
            headers: { "Authorization" => "Bearer #{@token}", "Accept" => "application/json" },
            request: { open_timeout: 3, timeout: 5 }) do |builder|
          builder.response :json
          builder.adapter(*Tmdb.adapter)
        end
      end
  end
end
