require "test_helper"

class Groups::Lists::ListEntries::RecommendationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @group = create(:group, members: [ @user ])
    @list = create(:list, group: @group)
    @entry = @list.add(create(:movie, name: "Arrival"), recommendation: "Pat loved it")
    sign_in_as @user
  end

  test "the list shows each entry's recommendation" do
    get group_list_path(@group, @list)

    assert_select "ol > li .recommendation", "“Pat loved it”"
  end

  test "an entry's page shows its recommendation, with a way to edit it" do
    get group_list_list_entry_path(@group, @list, @entry)

    assert_select "turbo-frame#recommendation blockquote", "“Pat loved it”"
    assert_select "turbo-frame#recommendation a[href=?]", edit_group_list_list_entry_recommendation_path(@group, @list, @entry),
      text: "Edit recommendation"
  end

  test "an entry without one offers to add one" do
    entry = @list.add(create(:movie))

    get group_list_list_entry_path(@group, @list, entry)

    assert_select "turbo-frame#recommendation a", "Add a recommendation"
  end

  test "editing opens the form in place" do
    get edit_group_list_list_entry_recommendation_path(@group, @list, @entry)

    assert_response :success
    assert_select "turbo-frame#recommendation form[data-turbo-frame=_top] input[name=?][value=?]",
      "list_entry[recommendation]", "Pat loved it"
  end

  test "saving a new recommendation" do
    patch group_list_list_entry_recommendation_path(@group, @list, @entry), params: { list_entry: { recommendation: "Everyone loved it" } }

    assert_redirected_to group_list_list_entry_path(@group, @list, @entry)
    assert_equal "Everyone loved it", @entry.reload.recommendation
  end

  test "clearing it removes the recommendation" do
    patch group_list_list_entry_recommendation_path(@group, @list, @entry), params: { list_entry: { recommendation: " " } }

    assert_nil @entry.reload.recommendation
  end

  test "a recommendation that's too long is refused" do
    patch group_list_list_entry_recommendation_path(@group, @list, @entry), params: { list_entry: { recommendation: "a" * 501 } }

    assert_response :unprocessable_content
    assert_select ".alert-danger", /too long/
    assert_equal "Pat loved it", @entry.reload.recommendation
  end

  test "another group's entries can't be edited" do
    others = create(:list)
    entry = others.add(create(:movie))

    patch group_list_list_entry_recommendation_path(others.group, others, entry), params: { list_entry: { recommendation: "Mine" } }

    assert_response :not_found
    assert_nil entry.reload.recommendation
  end
end
