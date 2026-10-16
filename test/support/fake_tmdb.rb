# Answers Tmdb::Client's requests from recorded, trimmed TMDB responses in
# test/fixtures/files/tmdb/, so tests never touch the network. A request maps to a fixture by its
# path: movie/329865 is movie-329865.json, tv/136315/season/1 is tv-136315-season-1.json, and a
# search for "The Bear" is search-the-bear.json. Unrecorded searches find nothing, and other
# unrecorded paths are TMDB's 404.
module FakeTmdb
  FIXTURES = Rails.root.join("test/fixtures/files/tmdb")
  JSON_HEADERS = { "Content-Type" => "application/json" }.freeze
  # Served by a tiny placeholder app in system tests (see ApplicationSystemTestCase).
  IMAGE_BASE_URL = "/fake_tmdb_images/"

  mattr_accessor :unreachable, default: false
  mattr_accessor :last_request

  def self.install
    Tmdb.image_base_url = IMAGE_BASE_URL
    Tmdb.adapter = [ :test, stubs ]
  end

  def self.stubs
    Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get(%r{\A/3/}) { |env| respond_to_request(env) }
    end
  end

  def self.respond_to_request(env)
    self.last_request = env
    raise Faraday::ConnectionFailed, "TMDB is unreachable (FakeTmdb.unreachable)" if unreachable

    path = env.url.path.delete_prefix("/3/")
    name = path == "search/multi" ? "search-#{env.params["query"].to_s.parameterize}" : path.tr("/", "-")
    fixture = FIXTURES.join("#{name}.json")

    if fixture.exist?
      [ 200, JSON_HEADERS, fixture.read ]
    elsif path == "search/multi"
      [ 200, JSON_HEADERS, { page: 1, results: [] }.to_json ]
    else
      [ 404, JSON_HEADERS, { success: false, status_message: "The resource you requested could not be found." }.to_json ]
    end
  end
end

FakeTmdb.install
