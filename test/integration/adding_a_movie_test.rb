require "test_helper"

class AddingAMovieTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as create(:user)
  end

  test "the catalog links to the movie form" do
    get titles_path

    assert_select "a[href=?]", new_title_path, text: "Add a movie"
  end

  test "movie form asks for a name and release date" do
    get new_title_path

    assert_response :success
    assert_select "h1", "Add a movie"
    assert_select "input[name=?][value=?]", "title[kind]", "movie"
    assert_select "input[name=?]", "title[name]"
    assert_select "input[name=?][type=date]", "title[episodes_attributes][0][available_on]"
  end

  test "adding a movie creates its title and its one episode" do
    assert_difference [ "Title.count", "Episode.count" ], 1 do
      post titles_path, params: movie_params(name: "Arrival", available_on: "2016-11-11")
    end

    movie = Title.last
    assert_redirected_to title_path(movie)
    assert_equal "Added Arrival.", flash[:notice]
    assert movie.movie?
    assert_equal [ [ 1, Date.new(2016, 11, 11) ] ], movie.episodes.pluck(:number, :available_on)
  end

  test "the release date is optional" do
    post titles_path, params: movie_params(name: "Arrival", available_on: "")

    assert_nil Title.last.episodes.sole.available_on
  end

  test "a movie needs a name" do
    assert_no_difference "Title.count" do
      post titles_path, params: movie_params(name: "")
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger li", "Name can't be blank"
  end

  test "a movie can't be given more than one episode" do
    params = movie_params(name: "Arrival")
    params[:title][:episodes_attributes]["1"] = { number: "2" }

    assert_no_difference "Title.count" do
      post titles_path, params: params
    end
    assert_select ".alert-danger li", "A movie has exactly one episode"
  end

  test "only kinds with an entry form can be created" do
    post titles_path, params: movie_params(name: "Arrival").deep_merge(title: { kind: "../layouts/application" })

    assert Title.last.movie?
  end

  private
    def movie_params(name:, available_on: "")
      { title: { kind: "movie", name: name, episodes_attributes: { "0" => { number: "1", available_on: available_on } } } }
    end
end
