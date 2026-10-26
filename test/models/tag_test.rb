require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "factory builds a valid tag" do
    assert build(:tag).valid?
  end

  test "a name is required, squished, and short" do
    assert_not build(:tag, name: " ").valid?
    assert_equal "Alice +", create(:tag, name: "  Alice   + ").name
    assert build(:tag, name: "x" * 20).valid?
    assert_not build(:tag, name: "x" * 21).valid?
  end

  test "a name is used once per list, ignoring case, but other lists can reuse it" do
    tag = create(:tag, name: "Alice+")

    duplicate = build(:tag, list: tag.list, name: "alice+")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "is already a tag on this list"
    assert build(:tag, name: "Alice+").valid?
  end

  test "the color comes from the palette" do
    assert_not build(:tag, color: "chartreuse").valid?
  end

  test "a new tag's color is the first the list isn't using yet" do
    list = create(:list)
    assert_equal "blue", Tag.next_color(list)

    create(:tag, list: list, color: "blue")
    create(:tag, list: list, color: "green")
    assert_equal "teal", Tag.next_color(list)
  end

  test "deleting a tag takes it off its entries" do
    tag = create(:tag)
    entry = tag.list.add(create(:movie))
    entry.tags << tag

    tag.destroy

    assert_empty entry.reload.tags
  end

  test "an entry can only carry its own list's tags, each once" do
    entry = create(:list).add(create(:movie))
    mine = create(:tag, list: entry.list)
    entry.tags << mine

    assert_not ListEntryTag.new(list_entry: entry, tag: mine).valid?
    assert_not ListEntryTag.new(list_entry: entry, tag: create(:tag)).valid?
  end
end
