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

  test "create returns 422 without a parent" do
    assert_no_difference "Folder.count" do
      post api_v1_folders_path, params: { folder: { name: "Orphan" } }, headers: api_headers(@token)
    end

    assert_response :unprocessable_entity
  end

  # Two requests racing past the validation: the rival row lands between the
  # uniqueness check and the insert, so only the unique index catches it.
  test "create returns 422 conflict when a duplicate races past the validation" do
    rival = ->(*, payload) do
      if !@raced && payload[:sql].start_with?('SELECT 1 AS one FROM "folders"')
        @raced = true
        Folder.insert!({ user_id: @user.id, parent_id: @root.id, name: "Archive" })
      end
    end

    ActiveSupport::Notifications.subscribed(rival, "sql.active_record") do
      post api_v1_folders_path,
        params: { folder: { name: "Archive", parent_id: @root.id } },
        headers: api_headers(@token)
    end

    assert_response :unprocessable_entity
    assert_equal "conflict", JSON.parse(response.body)["error"]
  end

  test "update renames and moves a folder" do
    patch api_v1_folder_path(@projects),
      params: { folder: { name: "Side projects", parent_id: @root.id } },
      headers: api_headers(@token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Side projects", json["name"]
    assert_equal @root.id, json["parent_id"]
    assert_equal "Side projects", @projects.reload.name
    assert_equal @root, @projects.parent
  end

  test "update returns 422 renaming to a sibling's name in another case" do
    current_user_folder("Archive")

    patch api_v1_folder_path(@work), params: { folder: { name: "ARCHIVE" } }, headers: api_headers(@token)

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"]["name"], "already exists in this folder"
    assert_equal "Work", @work.reload.name
  end

  test "update returns 422 for a name with a slash" do
    patch api_v1_folder_path(@work), params: { folder: { name: "a/b" } }, headers: api_headers(@token)

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"]["name"], "can't contain a slash"
  end

  test "update returns 422 moving a folder into its own descendant" do
    patch api_v1_folder_path(@work), params: { folder: { parent_id: @projects.id } }, headers: api_headers(@token)

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"]["parent"], "would create a circular reference"
    assert_equal @root, @work.reload.parent
  end

  test "update returns 422 renaming the root" do
    patch api_v1_folder_path(@root), params: { folder: { name: "Home" } }, headers: api_headers(@token)

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"]["base"], "Root folder cannot be modified"
    assert_equal "/", @root.reload.name
  end

  test "update returns 422 moving a folder under another user's folder" do
    patch api_v1_folder_path(@work),
      params: { folder: { parent_id: folders(:other_user_folder).id } },
      headers: api_headers(@token)

    assert_response :unprocessable_entity
    assert_equal @root, @work.reload.parent
  end

  test "update returns 404 for another user's folder" do
    patch api_v1_folder_path(folders(:other_user_folder)),
      params: { folder: { name: "Mine now" } },
      headers: api_headers(@token)

    assert_response :not_found
    assert_equal "Personal", folders(:other_user_folder).reload.name
  end

  test "update requires write scope" do
    read_only = create_access_token(user: @user, scopes: "read")
    patch api_v1_folder_path(@work), params: { folder: { name: "X" } }, headers: api_headers(read_only)

    assert_response :forbidden
    assert_equal "Work", @work.reload.name
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
