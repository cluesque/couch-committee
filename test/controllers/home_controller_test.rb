require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "renders the home page inside the signed-in layout" do
    sign_in_as create(:user, display_name: "Pat")

    get root_path

    assert_response :success
    assert_select "nav .navbar-brand", "Couch Committee"
    assert_select "nav", text: /Pat/
    assert_select "nav button", "Sign out"
    assert_select "h1", "Couch Committee"
  end
end
