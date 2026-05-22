require "test_helper"

class Api::V1::FoldersControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = create_access_token(user: @user)
    @root = folders(:root_one)
    @work = folders(:work)
    @projects = folders(:projects)
  end

  test "index lists all folders for the current user" do
    get api_v1_folders_path, headers: api_headers(@token)

    assert_response :success
    json = JSON.parse(response.body)
    names = json.map { |f| f["name"] }
    assert_includes names, "/"
    assert_includes names, "Work"
    assert_includes names, "Projects"
    refute_includes names, "Personal"
  end

  test "index with path returns folder and immediate subfolders" do
    get api_v1_folders_path, params: { path: "/Work" }, headers: api_headers(@token)

    assert_response :success
    json = JSON.parse(response.body)
    names = json.map { |f| f["name"] }
    assert_includes names, "Work"
    assert_includes names, "Projects"
    refute_includes names, "/"
  end

  test "index with path and recursive=true returns subtree" do
    get api_v1_folders_path, params: { path: "/Work", recursive: true }, headers: api_headers(@token)

    assert_response :success
    json = JSON.parse(response.body)
    names = json.map { |f| f["name"] }
    assert_includes names, "Work"
    assert_includes names, "Projects"
  end

  test "show returns folder json" do
    get api_v1_folder_path(@work), headers: api_headers(@token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @work.id, json["id"]
    assert_equal "Work", json["name"]
    assert_equal @root.id, json["parent_id"]
    assert_equal false, json["root"]
  end

  test "show returns 404 for another user's folder" do
    get api_v1_folder_path(folders(:other_user_folder)), headers: api_headers(@token)
    assert_response :not_found
  end

  test "create makes a new folder" do
    assert_difference "Folder.count", 1 do
      post api_v1_folders_path,
        params: { folder: { name: "Archive", parent_id: @root.id } },
        headers: api_headers(@token)
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Archive", json["name"]
  end

  test "create returns 422 on duplicate sibling name" do
    post api_v1_folders_path,
      params: { folder: { name: "Work", parent_id: @root.id } },
      headers: api_headers(@token)

    assert_response :unprocessable_entity
  end

  test "create requires write scope" do
    read_only = create_access_token(user: @user, scopes: "read")
    post api_v1_folders_path,
      params: { folder: { name: "X", parent_id: @root.id } },
      headers: api_headers(read_only)

    assert_response :forbidden
  end

  test "destroy removes an empty folder" do
    empty = current_user_folder("Empty")
    assert_difference "Folder.count", -1 do
      delete api_v1_folder_path(empty), headers: api_headers(@token)
    end
    assert_response :no_content
  end

  test "destroy returns 422 for a folder with notes" do
    delete api_v1_folder_path(folders(:work)), headers: api_headers(@token)
    assert_response :unprocessable_entity
  end

  test "index without token returns 401" do
    get api_v1_folders_path
    assert_response :unauthorized
  end

  private
    def current_user_folder(name)
      @user.folders.create!(name: name, parent: @root)
    end
end
