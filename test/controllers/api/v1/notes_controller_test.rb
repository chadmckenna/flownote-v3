require "test_helper"

class Api::V1::NotesControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = create_access_token(user: @user)
    @root = folders(:root_one)
    @work = folders(:work)
    @note = notes(:one)
  end

  test "index lists notes in a folder" do
    get api_v1_folder_notes_path(@work), headers: api_headers(@token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal @note.id, json.first["id"]
    assert_equal "First note", json.first["title"]
    refute json.first.key?("body")
  end

  test "show returns full note including body" do
    get api_v1_note_path(@note), headers: api_headers(@token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @note.id, json["id"]
    assert_equal @note.title, json["title"]
    assert_equal @note.body, json["body"]
  end

  test "show returns 404 for another user's note" do
    get api_v1_note_path(notes(:two)), headers: api_headers(@token)
    assert_response :not_found
  end

  test "create makes a new note" do
    assert_difference "Note.count", 1 do
      post api_v1_notes_path,
        params: { note: { title: "API note", body: "Hello **world**", folder_id: @work.id } },
        headers: api_headers(@token)
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "API note", json["title"]
    assert_equal "Hello **world**", json["body"]
  end

  test "create returns 422 without title" do
    post api_v1_notes_path,
      params: { note: { title: "", body: "Body", folder_id: @work.id } },
      headers: api_headers(@token)

    assert_response :unprocessable_entity
  end

  test "create requires write scope" do
    read_only = create_access_token(user: @user, scopes: "read")
    post api_v1_notes_path,
      params: { note: { title: "X", body: "Y", folder_id: @work.id } },
      headers: api_headers(read_only)

    assert_response :forbidden
  end

  test "update modifies note body" do
    patch api_v1_note_path(@note),
      params: { note: { body: "Updated body" } },
      headers: api_headers(@token)

    assert_response :success
    assert_equal "Updated body", @note.reload.body
  end

  test "destroy removes the note" do
    assert_difference "Note.count", -1 do
      delete api_v1_note_path(@note), headers: api_headers(@token)
    end
    assert_response :no_content
  end

  test "show without token returns 401" do
    get api_v1_note_path(@note)
    assert_response :unauthorized
  end
end
