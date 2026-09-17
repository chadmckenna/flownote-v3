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

  test "allows empty body" do
    note = users(:one).notes.build(title: "Test", body: "", folder: folders(:root_one))
    assert note.valid?
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

  test "rejects a folder belonging to another user" do
    note = users(:one).notes.build(title: "Planted", body: "x", folder: folders(:root_two))

    assert_not note.valid?
    assert_includes note.errors[:folder], "must belong to the same user"
  end

  test "rejects being moved into another user's folder" do
    note = notes(:one)

    assert_not note.update(folder: folders(:other_user_folder))
    assert_equal folders(:work), note.reload.folder
  end

  test "accepts any folder the owner owns" do
    note = users(:one).notes.build(title: "Fine", body: "x", folder: folders(:projects))

    assert_predicate note, :valid?
  end

  test "publish! assigns a short alphanumeric slug" do
    note = notes(:one)
    assert_not_predicate note, :published?

    note.publish!

    assert_predicate note, :published?
    assert_match(/\A[a-z0-9]{8}\z/, note.slug)
  end

  test "unpublish! clears the slug" do
    note = notes(:published)

    note.unpublish!

    assert_nil note.slug
    assert_not_predicate note, :published?
  end

  test "republishing mints a different slug" do
    note = notes(:published)
    original = note.slug

    note.unpublish!
    note.publish!

    assert_not_equal original, note.slug
  end

  test "published scope returns only notes with a slug" do
    assert_equal [ notes(:published) ], Note.published.to_a
  end

  test "rejects a title already used in the same folder" do
    note = users(:one).notes.build(title: notes(:one).title, body: "x", folder: folders(:work))

    assert_not note.valid?
    assert_includes note.errors[:title], "already exists in this folder"
  end

  test "accepts the same title in a different folder" do
    note = users(:one).notes.build(title: notes(:one).title, body: "x", folder: folders(:projects))

    assert_predicate note, :valid?
  end

  test "rejects being moved into a folder that already has the title" do
    note = users(:one).notes.create!(title: notes(:one).title, body: "x", folder: folders(:projects))

    assert_not note.update(folder: folders(:work))
    assert_equal folders(:projects), note.reload.folder
  end

  test "the database refuses a duplicate title the validation didn't catch" do
    duplicate = users(:one).notes.build(title: notes(:one).title, body: "x", folder: folders(:work))

    assert_raises ActiveRecord::RecordNotUnique do
      duplicate.save!(validate: false)
    end
  end

  test "slug must be unique" do
    note = notes(:one)
    note.slug = notes(:published).slug

    assert_not note.valid?
    assert_includes note.errors[:slug], "has already been taken"
  end
end
