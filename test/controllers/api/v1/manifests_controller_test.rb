require "test_helper"

class Api::V1::ManifestsControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = create_access_token(user: @user)
    @root = folders(:root_one)
    @work = folders(:work)
  end

  test "show returns the folder subtree and its notes with body hashes" do
    get api_v1_folder_manifest_path(@root), headers: api_headers(@token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [ "/", "Work", "Projects" ].sort, json["folders"].map { |f| f["name"] }.sort
    assert_equal [ notes(:one), notes(:root_note), notes(:published) ].map(&:id).sort, json["notes"].map { |n| n["id"] }

    note = json["notes"].find { |n| n["id"] == notes(:one).id }
    assert_equal Digest::SHA256.hexdigest(notes(:one).body), note["body_sha256"]
    assert_equal "First note", note["title"]
    assert_equal @work.id, note["folder_id"]
    assert_nil note["public_url"]
    refute note.key?("body")

    published = json["notes"].find { |n| n["id"] == notes(:published).id }
    assert_equal "http://www.example.com/~userone/abc12345", published["public_url"]
  end

  test "show of a subfolder leaves out notes above it" do
    get api_v1_folder_manifest_path(@work), headers: api_headers(@token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [ "Projects", "Work" ], json["folders"].map { |f| f["name"] }.sort
    assert_equal [ notes(:one), notes(:published) ].map(&:id).sort, json["notes"].map { |n| n["id"] }
  end

  test "show hashes a nil body as empty" do
    notes(:one).update_column(:body, nil)

    get api_v1_folder_manifest_path(@work), headers: api_headers(@token)

    note = JSON.parse(response.body)["notes"].find { |n| n["id"] == notes(:one).id }
    assert_equal Digest::SHA256.hexdigest(""), note["body_sha256"]
  end

  test "show omits a pre-existing cross-user note" do
    intruder = Note.new(title: "PLANTED", body: "x", user: users(:two), folder: @work)
    intruder.save!(validate: false)

    get api_v1_folder_manifest_path(@work), headers: api_headers(@token)

    assert_response :success
    assert_no_match(/PLANTED/, response.body)
  end

  test "show returns 404 for another user's folder" do
    get api_v1_folder_manifest_path(folders(:other_user_folder)), headers: api_headers(@token)
    assert_response :not_found
  end

  test "show without token returns 401" do
    get api_v1_folder_manifest_path(@root)
    assert_response :unauthorized
  end
end
