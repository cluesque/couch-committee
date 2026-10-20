require "test_helper"

class WelcomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, display_name: "Pat Smith", welcomed_at: nil)
    @just_me = create(:list, name: List::JUST_ME, members: [ @user ])
    sign_in_as @user
  end

  test "Home sends someone who hasn't been welcomed to the welcome page" do
    get root_path

    assert_redirected_to welcome_path
  end

  test "the welcome page introduces the app, once" do
    get welcome_path

    assert_select "h1", "Welcome, Pat!"
    assert_equal [ "Lists", "Add titles", "Put them in order", "Mark as watched", "Look back, and find it" ],
      css_select(".welcome-steps h2").map(&:text)
    assert_select "form[action=?] button", welcome_path, text: "Get started"
    assert_select "main > p.small a", count: 0 # no way around it but through
  end

  test "getting started marks me welcomed and opens my Just Me list" do
    freeze_time do
      patch welcome_path

      assert_redirected_to list_path(@just_me)
      assert_equal Time.current, @user.reload.welcomed_at
    end

    get root_path
    assert_response :success
  end

  test "getting started without a Just Me list goes Home" do
    @just_me.soft_delete

    patch welcome_path

    assert_redirected_to root_path
  end

  test "the account menu reopens it as \"How it works\", without asking to get started again" do
    welcomed_at = 1.week.ago.round
    @user.update!(welcomed_at: welcomed_at)

    get root_path
    assert_select ".dropdown-menu a[href=?]", welcome_path, text: "How it works"

    get welcome_path
    assert_select "h1", "How it works"
    assert_select "a[href=?]", root_path, text: "Back to your lists"
    assert_select "button", text: "Get started", count: 0

    patch welcome_path
    assert_equal welcomed_at, @user.reload.welcomed_at
  end

  test "someone with no display name is welcomed without one" do
    @user.update!(display_name: nil)

    get welcome_path

    assert_select "h1", "Welcome!"
  end
end
