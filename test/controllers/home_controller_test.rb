require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "renders the home page inside the layout" do
    get root_path

    assert_response :success
    assert_select "nav .navbar-brand", "Couch Committee"
    assert_select "h1", "Couch Committee"
  end
end
