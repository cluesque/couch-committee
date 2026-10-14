# Plays Google's part of the OAuth round-trip so tests exercise the real google_sign_in engine
# without network access: a token endpoint (via a Faraday test adapter) and ID-token verification
# (via GoogleSignIn::Identity's swappable validator). An authorization code doubles as the ID token
# it's exchanged for, and maps to the claims registered for it.
module FakeGoogle
  mattr_accessor :claims_by_token, default: {}
  # The code the fake consent screen (system tests only) hands back to the app.
  mattr_accessor :next_authorization_code

  def self.install
    GoogleSignIn.client_id = "test-client-id"
    GoogleSignIn.client_secret = "test-client-secret"
    GoogleSignIn::Identity.validator = Validator.new
    GoogleSignIn.oauth2_client_options = {
      connection_build: ->(builder) {
        builder.request :url_encoded
        builder.adapter :test, token_endpoint
      }
    }
  end

  def self.authorization_code_for(sub:, email:, name: nil, email_verified: true)
    SecureRandom.hex.tap do |code|
      claims_by_token[code] = { "sub" => sub, "email" => email, "name" => name, "email_verified" => email_verified }
    end
  end

  def self.token_endpoint
    Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post(GoogleSignIn.token_url) do |env|
        code = Rack::Utils.parse_query(env.body)["code"]
        [ 200, { "Content-Type" => "application/json" }, { access_token: "fake", token_type: "Bearer", id_token: code }.to_json ]
      end
    end
  end

  # Mounted in front of the app for system tests; skips the consent screen and sends the browser
  # straight back to the app's callback, like Google does for an already-consented account.
  ConsentScreen = ->(env) do
    params = Rack::Utils.parse_query(env["QUERY_STRING"])
    query = { code: FakeGoogle.next_authorization_code, state: params["state"] }.to_query
    [ 302, { "location" => "#{params["redirect_uri"]}?#{query}" }, [] ]
  end

  class Validator
    def check(token, _client_id)
      FakeGoogle.claims_by_token.fetch(token) { raise GoogleIDToken::ValidationError, "unknown token" }
    end
  end
end

FakeGoogle.install
