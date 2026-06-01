require "test_helper"

class FoldersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @root = folders(:root_one)
    @folder = folders(:work)
    sign_in_as(@user)
  end

  test "index" do
    get root_path
    assert_response :success
  end

  test "show" do
    get folder_path(@folder)
    assert_response :success
  end

  test "show renders the full editor shell (no content frame)" do
    get folder_path(@folder)
    assert_response :success
    assert_select "main.folder-shell .folder-shell__sidebar"
    assert_select ".folder-shell__main"
    assert_select "turbo-frame#editor_main", false
  end

  test "show root folder redirects to root" do
    get folder_path(@root)
    assert_redirected_to root_path
  end

  test "new" do
    get new_folder_path
    assert_response :success
  end

  test "new with parent" do
    get new_folder_path(parent_id: @folder.id)
    assert_response :success
  end

  test "create" do
    assert_difference("Folder.count") do
      post folders_path, params: { folder: { name: "New folder", parent_id: @root.id } }
    end

    assert_redirected_to root_path
  end

  test "create with non-root parent" do
    assert_difference("Folder.count") do
      post folders_path, params: { folder: { name: "Child", parent_id: @folder.id } }
    end

    assert_redirected_to folder_path(@folder)
  end

  test "create with missing name" do
    assert_no_difference("Folder.count") do
      post folders_path, params: { folder: { name: "", parent_id: @root.id } }
    end

    assert_response :unprocessable_entity
  end

  test "edit" do
    get edit_folder_path(@folder)
    assert_response :success
  end

  test "cannot edit root folder" do
    get edit_folder_path(@root)
    assert_response :not_found
  end

  test "update" do
    patch folder_path(@folder), params: { folder: { name: "Renamed" } }
    assert_redirected_to folder_path(@folder)
    assert_equal "Renamed", @folder.reload.name
  end

  test "cannot update root folder" do
    patch folder_path(@root), params: { folder: { name: "Renamed" } }
    assert_response :not_found
  end

  test "destroy empty folder" do
    empty = @user.folders.create!(name: "Empty", parent: @root)
    assert_difference("Folder.count", -1) do
      delete folder_path(empty)
    end
    assert_redirected_to root_path
  end

  test "cannot destroy folder with contents" do
    assert_no_difference("Folder.count") do
      delete folder_path(@folder)
    end
    assert_redirected_to folder_path(@folder)
  end

  test "cannot destroy root folder" do
    delete folder_path(@root)
    assert_response :not_found
  end

  test "cannot access another user's folder" do
    other_folder = folders(:other_user_folder)
    get folder_path(other_folder)
    assert_response :not_found
  end

  test "requires authentication" do
    sign_out
    get folder_path(@folder)
    assert_redirected_to new_session_path
  end
end
