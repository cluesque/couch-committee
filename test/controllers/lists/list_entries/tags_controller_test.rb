require "test_helper"

class Lists::ListEntries::TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @list = create(:list, members: [ @user ], name: "Movie night")
    @entry = @list.add(create(:movie, name: "Arrival"))
    @alice = create(:tag, list: @list, name: "Alice+", color: "purple")
    @cozy = create(:tag, list: @list, name: "Cozy", color: "orange")
    sign_in_as @user
  end

  test "an entry's page offers to add tags, then shows them" do
    get list_list_entry_path(@list, @entry)
    assert_select "turbo-frame#tags a[href=?]", edit_list_list_entry_tags_path(@list, @entry), text: "Add tags"

    @entry.tags << @alice
    get list_list_entry_path(@list, @entry)
    assert_select "turbo-frame#tags .tag.tag-purple", "Alice+"
    assert_select "turbo-frame#tags a", text: "Edit tags"
  end

  test "the form lists the list's tags to tick, and a new tag with the next unused color" do
    @entry.tags << @cozy

    get edit_list_list_entry_tags_path(@list, @entry)

    assert_select "turbo-frame#tags form[data-turbo-frame=_top]"
    assert_select "input[type=checkbox]", count: 2
    assert_select "input[type=checkbox][value=?]:not([checked])", @alice.id.to_s
    assert_select "input[type=checkbox][value=?][checked]", @cozy.id.to_s
    assert_select "input[name=?][placeholder=?]", "new_tag[name]", "e.g. Alice+"
    assert_select "input[type=radio][name=?][value=blue][checked]", "new_tag[color]"
  end

  test "ticking and unticking tags" do
    @entry.tags << @cozy

    patch list_list_entry_tags_path(@list, @entry), params: { list_entry: { tag_ids: [ "", @alice.id ] } }

    assert_redirected_to list_list_entry_path(@list, @entry)
    assert_equal [ @alice ], @entry.reload.tags
  end

  test "unticking every tag takes them all off" do
    @entry.tags << @cozy

    patch list_list_entry_tags_path(@list, @entry), params: { list_entry: { tag_ids: [ "" ] } }

    assert_empty @entry.reload.tags
  end

  test "making a new tag puts it on the entry, alongside those ticked" do
    assert_difference "@list.tags.count", 1 do
      patch list_list_entry_tags_path(@list, @entry),
        params: { list_entry: { tag_ids: [ "", @cozy.id ] }, new_tag: { name: " Long ", color: "teal" } }
    end

    long = @list.tags.find_by!(name: "Long")
    assert_equal "teal", long.color
    assert_equal [ @cozy, long ], @entry.reload.tags
  end

  test "a new tag that's invalid shows the form again, keeping what was ticked" do
    assert_no_difference [ "Tag.count", "ListEntryTag.count" ] do
      patch list_list_entry_tags_path(@list, @entry),
        params: { list_entry: { tag_ids: [ "", @cozy.id ] }, new_tag: { name: "alice+", color: "teal" } }
    end

    assert_response :unprocessable_content
    assert_select ".alert", text: /Name is already a tag on this list/
    assert_select "input[type=checkbox][value=?][checked]", @cozy.id.to_s
    assert_select "input[name=?][value=?]", "new_tag[name]", "alice+"
    assert_select "input[type=radio][value=teal][checked]"
    assert_select "input[type=checkbox]", count: 2
  end

  test "another list's tags are ignored" do
    theirs = create(:tag)

    patch list_list_entry_tags_path(@list, @entry), params: { list_entry: { tag_ids: [ theirs.id ] } }

    assert_empty @entry.reload.tags
  end

  test "someone else's entries can't be tagged" do
    entry = create(:list).add(create(:movie))

    get edit_list_list_entry_tags_path(entry.list, entry)
    assert_response :not_found

    patch list_list_entry_tags_path(entry.list, entry), params: { new_tag: { name: "Mine", color: "blue" } }
    assert_response :not_found
    assert_equal 0, entry.list.tags.count
  end
end
