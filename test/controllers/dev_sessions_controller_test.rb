require "test_helper"

class DevSessionsControllerTest < ActionDispatch::IntegrationTest
  teardown do
    Rails.configuration.x.dev_sign_in = true
  end

  test "sign-in page offers dev sign-in" do
    get new_session_path

    assert_select "form[action=?]", dev_session_path do
      assert_select "input[type=email][name=email]"
      assert_select "input[type=submit][value=?]", "Dev sign-in"
    end
  end

  test "dev sign-in creates someone new, with a Just Me list, and welcomes them" do
    assert_difference [ "User.count", "Session.count" ], 1 do
      post dev_session_path, params: { email: " Pat@Example.com ", name: "Pat" }
    end

    user = User.find_by!(email: "pat@example.com")
    assert_equal "Pat", user.display_name
    assert_nil user.google_id
    assert_equal [ List::JUST_ME ], user.lists.map(&:name)

    assert_redirected_to root_url
    follow_redirect!
    assert_redirected_to welcome_path
  end

  test "dev sign-in signs in as an existing Google user, unchanged" do
    user = create(:user, display_name: "Sam")
    user.create_just_me_list

    assert_no_difference [ "User.count", "List.count" ] do
      post dev_session_path, params: { email: user.email, name: "Someone Else" }
    end

    assert_redirected_to root_url
    assert_equal "Sam", user.reload.display_name
    assert_equal user, Session.last.user
  end

  test "dev sign-in claims an invited user, and signing in again adds nothing" do
    user = create(:user, :invited)

    post dev_session_path, params: { email: user.email, name: "Alex" }
    delete session_path
    assert_no_difference "List.count" do
      post dev_session_path, params: { email: user.email }
    end

    assert_equal "Alex", user.reload.display_name
    assert_equal [ List::JUST_ME ], user.lists.map(&:name)
  end

  test "dev sign-in returns to the page originally requested" do
    get root_path(from: "bookmark")

    post dev_session_path, params: { email: create(:user).email }

    assert_redirected_to root_url(from: "bookmark")
  end

  test "dev sign-in refuses something that isn't an email" do
    assert_no_difference [ "User.count", "Session.count" ] do
      post dev_session_path, params: { email: "not an email" }
    end

    assert_redirected_to new_session_path
    assert_equal "Sorry, that doesn't look like an email address.", flash[:alert]
  end

  test "without dev sign-in turned on, it's not there" do
    Rails.configuration.x.dev_sign_in = false

    get new_session_path
    assert_select "form[action=?]", dev_session_path, count: 0

    assert_no_difference [ "User.count", "Session.count" ] do
      post dev_session_path, params: { email: "pat@example.com" }
    end
    assert_response :not_found
  end
end
