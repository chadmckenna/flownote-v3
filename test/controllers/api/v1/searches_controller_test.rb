require "test_helper"

class Api::V1::SearchesControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = create_access_token(user: @user)
  end

  test "show returns matching notes with their folder path" do
    get api_v1_search_path, params: { q: "shared" }, headers: api_headers(@token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [ notes(:published).id ], json.map { |n| n["id"] }
    assert_equal "Work/Projects", json.first["path"]
    assert_equal "http://www.example.com/~userone/abc12345", json.first["public_url"]
    refute json.first.key?("body")
  end

  test "show with folder_id searches that folder and below only" do
    get api_v1_search_path, params: { q: "note", folder_id: folders(:work).id }, headers: api_headers(@token)

    assert_response :success
    ids = JSON.parse(response.body).map { |n| n["id"] }
    assert_includes ids, notes(:one).id
    assert_includes ids, notes(:published).id
    assert_not_includes ids, notes(:root_note).id
  end

  test "show with another user's folder_id returns 404" do
    get api_v1_search_path, params: { q: "note", folder_id: folders(:other_user_folder).id }, headers: api_headers(@token)
    assert_response :not_found
  end

  test "show gives a note in the root folder an empty path" do
    get api_v1_search_path, params: { q: "root note" }, headers: api_headers(@token)

    json = JSON.parse(response.body)
    assert_equal [ notes(:root_note).id ], json.map { |n| n["id"] }
    assert_equal "", json.first["path"]
  end

  test "show leaves out other users' notes" do
    get api_v1_search_path, params: { q: "note" }, headers: api_headers(@token)

    assert_response :success
    ids = JSON.parse(response.body).map { |n| n["id"] }
    assert_equal [ notes(:one), notes(:root_note), notes(:published) ].map(&:id).sort, ids.sort
  end

  test "show with a blank or missing query returns an empty list" do
    get api_v1_search_path, params: { q: " " }, headers: api_headers(@token)
    assert_equal [], JSON.parse(response.body)

    get api_v1_search_path, headers: api_headers(@token)
    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test "show without token returns 401" do
    get api_v1_search_path, params: { q: "note" }
    assert_response :unauthorized
  end
end
