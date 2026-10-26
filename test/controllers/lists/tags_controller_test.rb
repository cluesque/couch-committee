require "test_helper"

class Lists::TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @list = create(:list, members: [ @user ], name: "Movie night")
    @tag = create(:tag, list: @list, name: "Alice+", color: "purple")
    sign_in_as @user
  end

  test "the list's edit page shows its tags, each with how many entries have it" do
    2.times { @list.add(create(:movie)).tags << @tag }

    get edit_list_path(@list)

    assert_select ".list-tags turbo-frame", text: /Alice\+\s+2 entries/
    assert_select ".list-tags a[href=?]", edit_list_tag_path(@list, @tag)
  end

  test "a list with no tags says where they come from" do
    @tag.destroy

    get edit_list_path(@list)

    assert_select "p", text: /No tags yet\. Add them from any entry's page/
  end

  test "renaming and recoloring a tag" do
    get edit_list_tag_path(@list, @tag)
    assert_select "turbo-frame form input[name=?][value=?]", "tag[name]", "Alice+"
    assert_select "input[type=radio][name=?][value=purple][checked]", "tag[color]"

    patch list_tag_path(@list, @tag), params: { tag: { name: "With Alice", color: "green" } }

    assert_redirected_to edit_list_path(@list)
    assert_equal "Saved With Alice.", flash[:notice]
    assert_equal [ "With Alice", "green" ], @tag.reload.values_at(:name, :color)
  end

  test "an invalid change shows the form again" do
    patch list_tag_path(@list, @tag), params: { tag: { name: "" } }

    assert_response :unprocessable_content
    assert_select ".alert", text: /Name can't be blank/
  end

  test "deleting a tag, warning which entries it comes off" do
    entry = @list.add(create(:movie))
    entry.tags << @tag

    get edit_list_tag_path(@list, @tag)
    assert_select "form[data-turbo-confirm=?] button", "Delete Alice+? It comes off 1 entry.", text: "Delete tag"

    delete list_tag_path(@list, @tag)

    assert_redirected_to edit_list_path(@list)
    assert_equal "Deleted Alice+.", flash[:notice]
    assert_not Tag.exists?(@tag.id)
    assert_empty entry.reload.tags
  end

  test "someone else's tags are not found" do
    theirs = create(:tag)

    get edit_list_tag_path(theirs.list, theirs)
    assert_response :not_found

    delete list_tag_path(theirs.list, theirs)
    assert_response :not_found
    assert Tag.exists?(theirs.id)
  end
end
