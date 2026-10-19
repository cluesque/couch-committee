require "test_helper"

class ErrorPagesTest < ActionDispatch::IntegrationTest
  setup do
    @detailed = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    # As in production, where errors render public/<status>.html instead of the debug page.
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
    sign_in_as create(:user)
  end

  teardown do
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @detailed
  end

  test "a list you're not on gets the friendly not-found page, with a way home" do
    get list_path(create(:list))

    assert_response :not_found
    assert_select "h1", "There's nothing here"
    assert_select "a[href='/']", "Back to Couch Committee"
  end
end
