require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "factory builds a valid user" do
    assert build(:user).valid?
  end

  test "requires an email" do
    assert_not build(:user, email: "").valid?
  end

  test "requires a plausible email address" do
    assert_not build(:user, email: "pat at example.com").valid?
  end

  test "normalizes email to lowercase without surrounding whitespace" do
    assert_equal "pat@example.com", create(:user, email: "  Pat@Example.COM ").email
  end

  test "email is unique regardless of case" do
    create(:user, email: "pat@example.com")

    assert_not build(:user, email: "PAT@example.com").valid?
  end

  test "google_id is unique when present" do
    create(:user, google_id: "abc")

    assert_not build(:user, google_id: "abc").valid?
  end

  test "an invited user has neither a google_id nor a display name" do
    assert build(:user, :invited).valid?
  end

  test "name falls back to email when there is no display name" do
    assert_equal "Pat", build(:user, display_name: "Pat").name
    assert_equal "pat@example.com", build(:user, :invited, email: "pat@example.com").name
  end

  test "from_google creates a user on first sign-in" do
    user = User.from_google(google_identity(sub: "g-1", email: "Pat@Example.com", name: "Pat"))

    assert user.persisted?
    assert_equal [ "g-1", "pat@example.com", "Pat" ], [ user.google_id, user.email, user.display_name ]
  end

  test "from_google finds a returning user by google_id even if their email has changed" do
    user = create(:user, google_id: "g-1", email: "old@example.com")

    assert_equal user, User.from_google(google_identity(sub: "g-1", email: "new@example.com"))
  end

  test "from_google claims an invited user with the same email" do
    invited = create(:user, :invited, email: "pat@example.com")

    user = User.from_google(google_identity(sub: "g-1", email: "pat@example.com", name: "Pat"))

    assert_equal invited, user
    assert_equal [ "g-1", "Pat" ], [ user.google_id, user.display_name ]
  end

  test "from_google keeps an existing display name when claiming a user" do
    create(:user, :invited, email: "pat@example.com", display_name: "Patricia")

    assert_equal "Patricia", User.from_google(google_identity(sub: "g-1", email: "pat@example.com", name: "Pat")).display_name
  end

  test "from_google refuses an email already linked to a different Google account" do
    create(:user, google_id: "g-1", email: "pat@example.com")

    assert_nil User.from_google(google_identity(sub: "g-2", email: "pat@example.com"))
  end

  test "from_google refuses an unverified email" do
    assert_no_difference "User.count" do
      assert_nil User.from_google(google_identity(sub: "g-1", email: "pat@example.com", email_verified: false))
    end
  end

  private
    def google_identity(**claims)
      GoogleSignIn::Identity.new(FakeGoogle.authorization_code_for(**claims))
    end
end
