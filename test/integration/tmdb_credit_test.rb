require "test_helper"

class TmdbCreditTest < ActionDispatch::IntegrationTest
  test "signed-out pages credit TMDB" do
    get new_session_path

    assert_tmdb_credit
  end

  test "signed-in pages credit TMDB" do
    sign_in_as create(:user)

    get root_path

    assert_tmdb_credit
  end

  private
    def assert_tmdb_credit
      assert_select "footer a[href='https://www.themoviedb.org/'] img[alt=TMDB]"
      assert_select "footer", text: /not endorsed or certified by TMDB/
    end
end
