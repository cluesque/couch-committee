require "test_helper"

class Groups::PlayLists::ListEntries::CancellationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @group = create(:group, members: [ @user ])
    @play_list = create(:play_list, group: @group)
    @entry = @play_list.add(create(:movie, name: "Arrival"))
    sign_in_as @user
  end

  test "an active entry's details offer to cancel it" do
    get group_play_list_list_entry_path(@group, @play_list, @entry)

    assert_select "turbo-frame#cancellation a[href=?]",
      new_group_play_list_list_entry_cancellation_path(@group, @play_list, @entry), text: "Cancel…"
  end

  test "the cancel form asks why, optionally" do
    get new_group_play_list_list_entry_cancellation_path(@group, @play_list, @entry)

    assert_response :success
    assert_select "turbo-frame#cancellation form[data-turbo-frame=_top] textarea[name=?]", "cancellation[note]"
    assert_select "input[type=submit][value=?]", "Cancel it"
  end

  test "cancelling with a note takes the entry off the playlist" do
    post group_play_list_list_entry_cancellation_path(@group, @play_list, @entry),
      params: { cancellation: { note: "Saw it on a plane." } }

    assert_redirected_to group_play_list_path(@group, @play_list)
    assert_equal "Cancelled Arrival.", flash[:notice]
    assert @entry.reload.cancelled?
    assert_equal "Saw it on a plane.", @entry.cancel_note

    follow_redirect!
    assert_select "li", text: /Arrival/, count: 0
  end

  test "cancelling without a note" do
    post group_play_list_list_entry_cancellation_path(@group, @play_list, @entry)

    assert @entry.reload.cancelled?
    assert_nil @entry.cancel_note
  end

  test "a cancelled entry's details show when and why, and offer neither watch nor cancel" do
    @entry.cancel(note: "Saw it on a plane.")

    get group_play_list_list_entry_path(@group, @play_list, @entry)

    assert_select ".alert", text: /Cancelled .*Saw it on a plane/
    assert_select "turbo-frame#watch", count: 0
    assert_select "turbo-frame#cancellation", count: 0
  end

  test "only active entries can be cancelled" do
    @entry.update!(state: :watched)

    post group_play_list_list_entry_cancellation_path(@group, @play_list, @entry)

    assert_response :not_found
    assert @entry.reload.watched?
  end

  test "another group's entry can't be cancelled" do
    others = create(:play_list)
    entry = others.add(create(:movie))

    post group_play_list_list_entry_cancellation_path(others.group, others, entry)

    assert_response :not_found
    assert entry.reload.not_started?
  end
end
