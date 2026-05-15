require "test_helper"

class NoteTest < ActiveSupport::TestCase
  test "valid note" do
    note = users(:one).notes.build(title: "Test", body: "Some content", folder: folders(:root_one))
    assert note.valid?
  end

  test "requires title" do
    note = users(:one).notes.build(title: "", body: "Some content", folder: folders(:root_one))
    assert_not note.valid?
    assert_includes note.errors[:title], "can't be blank"
  end

  test "requires body" do
    note = users(:one).notes.build(title: "Test", body: "", folder: folders(:root_one))
    assert_not note.valid?
    assert_includes note.errors[:body], "can't be blank"
  end

  test "requires folder" do
    note = users(:one).notes.build(title: "Test", body: "Content")
    assert_not note.valid?
    assert_includes note.errors[:folder], "must exist"
  end

  test "belongs to user" do
    assert_equal users(:one), notes(:one).user
  end

  test "belongs to folder" do
    assert_equal folders(:work), notes(:one).folder
  end
end
