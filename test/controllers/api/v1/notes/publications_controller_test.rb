require "test_helper"

class Api::V1::Notes::PublicationsControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = create_access_token(user: @user)
    @note = notes(:one)
  end

  test "create publishes the note and returns it with its public url" do
    post api_v1_note_publication_path(@note), headers: api_headers(@token)

    assert_response :success
    assert_predicate @note.reload, :published?
    json = JSON.parse(response.body)
    assert_equal "http://www.example.com/~userone/#{@note.slug}", json["public_url"]
    assert_equal @note.body, json["body"]
  end

  test "create on a published note keeps its slug and public url" do
    published = notes(:published)

    post api_v1_note_publication_path(published), headers: api_headers(@token)

    assert_response :success
    assert_equal "abc12345", published.reload.slug
    assert_equal "http://www.example.com/~userone/abc12345", JSON.parse(response.body)["public_url"]
  end

  test "create requires a username" do
    token = create_access_token(user: users(:two))

    post api_v1_note_publication_path(notes(:two)), headers: api_headers(token)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "username_required", json["error"]
    assert_includes json["message"], "http://www.example.com/me"
    assert_not_predicate notes(:two).reload, :published?
  end

  test "destroy unpublishes the note and clears its public url" do
    published = notes(:published)

    delete api_v1_note_publication_path(published), headers: api_headers(@token)

    assert_response :success
    assert_nil published.reload.slug
    json = JSON.parse(response.body)
    assert json.key?("public_url")
    assert_nil json["public_url"]
  end

  test "create requires write scope" do
    read_only = create_access_token(user: @user, scopes: "read")

    post api_v1_note_publication_path(@note), headers: api_headers(read_only)

    assert_response :forbidden
    assert_not_predicate @note.reload, :published?
  end

  test "destroy requires write scope" do
    read_only = create_access_token(user: @user, scopes: "read")

    delete api_v1_note_publication_path(notes(:published)), headers: api_headers(read_only)

    assert_response :forbidden
    assert_predicate notes(:published).reload, :published?
  end

  test "cannot publish another user's note" do
    post api_v1_note_publication_path(notes(:two)), headers: api_headers(@token)

    assert_response :not_found
    assert_not_predicate notes(:two).reload, :published?
  end

  test "cannot unpublish another user's note" do
    notes(:two).update_column(:slug, "theirs12")

    delete api_v1_note_publication_path(notes(:two)), headers: api_headers(@token)

    assert_response :not_found
    assert_equal "theirs12", notes(:two).reload.slug
  end

  test "create without token returns 401" do
    post api_v1_note_publication_path(@note)
    assert_response :unauthorized
  end
end
