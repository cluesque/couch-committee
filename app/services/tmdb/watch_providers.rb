module Tmdb
  # Where a title can be watched in one country, from TMDB's watch providers (data from JustWatch).
  # Availability changes too often to store, so it's fetched when shown and cached for a while. A
  # series' providers are the show's, shared by all its seasons.
  class WatchProviders
    COUNTRY = "US"
    CACHE_FOR = 6.hours

    Provider = Data.define(:name, :logo_path)

    attr_reader :stream, :rent, :buy, :link

    # Nil when TMDB can't be reached, or for a title that isn't from TMDB.
    def self.for(title, client: Client.new, cache: Rails.cache)
      return unless title.tmdb_id && (title.movie? || title.series?)

      json = cache.fetch([ "tmdb-watch-providers", title.kind, title.tmdb_id, COUNTRY ], expires_in: CACHE_FOR) do
        client.watch_providers(title.kind, title.tmdb_id)[COUNTRY] || {}
      end
      new(json)
    rescue Error
      nil
    end

    def initialize(json)
      @stream = providers(json, "flatrate", "free", "ads")
      @rent = providers(json, "rent")
      @buy = providers(json, "buy")
      @link = json["link"]
    end

    def any?
      [ stream, rent, buy ].any?(&:any?)
    end

    private
      # Most prominent first, and each provider once, even if it's both free and with ads.
      def providers(json, *kinds)
        kinds.flat_map { |kind| json[kind] || [] }
          .sort_by { |provider| provider["display_priority"].to_i }
          .uniq { |provider| provider["provider_id"] }
          .map { |provider| Provider.new(name: provider["provider_name"], logo_path: provider["logo_path"]) }
      end
  end
end
