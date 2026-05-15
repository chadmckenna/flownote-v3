require "test_helper"

class FolderTest < ActiveSupport::TestCase
  test "valid folder" do
    folder = users(:one).folders.build(name: "Test", parent: folders(:root_one))
    assert folder.valid?
  end

  test "requires name" do
    folder = users(:one).folders.build(name: "", parent: folders(:root_one))
    assert_not folder.valid?
    assert_includes folder.errors[:name], "can't be blank"
  end

  test "belongs to user" do
    assert_equal users(:one), folders(:work).user
  end

  test "can have a parent folder" do
    assert_equal folders(:work), folders(:projects).parent
  end

  test "root folder has no parent" do
    assert_nil folders(:root_one).parent
  end

  test "unique name within same parent and user" do
    duplicate = users(:one).folders.build(name: "Work", parent: folders(:root_one))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "already exists in this folder"
  end

  test "same name allowed in different parents" do
    folder = users(:one).folders.build(name: "Work", parent: folders(:work))
    assert folder.valid?
  end

  test "same name allowed for different users" do
    folder = users(:two).folders.build(name: "Work", parent: folders(:root_two))
    assert folder.valid?
  end

  test "parent must belong to same user" do
    folder = users(:one).folders.build(name: "Bad", parent: folders(:other_user_folder))
    assert_not folder.valid?
    assert_includes folder.errors[:parent], "must belong to the same user"
  end

  test "cannot delete folder with notes" do
    assert_not folders(:work).destroy
  end

  test "cannot delete folder with subfolders" do
    assert_not folders(:work).destroy
  end

  test "can delete empty folder" do
    empty = users(:one).folders.create!(name: "Empty", parent: folders(:root_one))
    assert empty.destroy
  end

  test "ancestors returns path to root" do
    assert_equal [ folders(:root_one), folders(:work) ], folders(:projects).ancestors
  end

  test "ancestors returns empty array for root folder" do
    assert_equal [], folders(:root_one).ancestors
  end

  test "root? returns true for root folder" do
    assert folders(:root_one).root?
  end

  test "root? returns false for non-root folder" do
    assert_not folders(:work).root?
  end

  test "root folder cannot be renamed" do
    root = folders(:root_one)
    root.name = "renamed"
    assert_not root.valid?
    assert_includes root.errors[:base], "Root folder cannot be modified"
  end

  test "root folder cannot be deleted" do
    assert_not folders(:root_one).destroy
  end

  test "user gets root folder on creation" do
    user = User.create!(email_address: "new@example.com", password: "password", password_confirmation: "password")
    assert user.root_folder.present?
    assert_equal "/", user.root_folder.name
  end
end
