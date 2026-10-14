require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "factory builds a valid user" do
    assert build(:user).valid?
  end

  test "requires an email" do
    assert_not build(:user, email: "").valid?
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
end
