# The Movie Database (themoviedb.org), where titles come from. See docs/title-metadata.md.
module Tmdb
  class Error < StandardError; end

  API_URL = "https://api.themoviedb.org/3/"

  # Tests swap these: images for a local placeholder, the adapter for canned responses.
  mattr_accessor :image_base_url, default: "https://image.tmdb.org/t/p/"
  mattr_accessor :adapter, default: [ Faraday.default_adapter ]

  # TMDB image sizes include w92, w154, w185, w342, w500, w780, and original.
  def self.image_url(path, size)
    "#{image_base_url}#{size}#{path}" if path.present?
  end
end
