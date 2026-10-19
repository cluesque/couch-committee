require "test_helper"

class Lists::ListEntries::CancellationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @list = create(:list, members: [ @user ])
    @entry = @list.add(create(:movie, name: "Arrival"))
    sign_in_as @user
  end

  test "an active entry's details offer to cancel it" do
    get list_list_entry_path(@list, @entry)

    assert_select "turbo-frame#cancellation a[href=?]",
      new_list_list_entry_cancellation_path(@list, @entry), text: "Remove from list…"
  end

  test "the cancel form asks why, optionally" do
    get new_list_list_entry_cancellation_path(@list, @entry)

    assert_response :success
    assert_select "turbo-frame#cancellation form[data-turbo-frame=_top] textarea[name=?]", "cancellation[note]"
    assert_select "input[type=submit][value=?]", "Remove it"
  end

  test "cancelling with a note takes the entry off the list" do
    post list_list_entry_cancellation_path(@list, @entry),
      params: { cancellation: { note: "Saw it on a plane." } }

    assert_redirected_to list_path(@list)
    assert_equal "Removed Arrival from #{@list.name}.", flash[:notice]
    assert @entry.reload.cancelled?
    assert_equal "Saw it on a plane.", @entry.cancel_note

    follow_redirect!
    assert_select "li", text: /Arrival/, count: 0
  end

  test "cancelling without a note" do
    post list_list_entry_cancellation_path(@list, @entry)

    assert @entry.reload.cancelled?
    assert_nil @entry.cancel_note
  end

  test "a cancelled entry's details show when and why, and offer neither watch nor cancel" do
    @entry.cancel(note: "Saw it on a plane.")

    get list_list_entry_path(@list, @entry)

    assert_select ".alert", text: /Removed .*Saw it on a plane/
    assert_select "turbo-frame#watch", count: 0
    assert_select "turbo-frame#cancellation", count: 0
  end

  test "only active entries can be cancelled" do
    @entry.update!(state: :watched)

    post list_list_entry_cancellation_path(@list, @entry)

    assert_response :not_found
    assert @entry.reload.watched?
  end

  test "someone else's entry can't be cancelled" do
    others = create(:list)
    entry = others.add(create(:movie))

    post list_list_entry_cancellation_path(others, entry)

    assert_response :not_found
    assert entry.reload.not_started?
  end
end
