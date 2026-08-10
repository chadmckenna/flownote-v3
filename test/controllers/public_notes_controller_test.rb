require "test_helper"

class PublicNotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @note = notes(:published)
    @username = users(:one).username
  end

  test "show renders without authentication" do
    get public_note_path(username: @username, slug: @note.slug)

    assert_response :success
    assert_select "h1", @note.title
    assert_select ".prose h2", "Shared"
  end

  test "show does not disclose the folder or the app shell" do
    get public_note_path(username: @username, slug: @note.slug)

    assert_select ".folder-shell", false
    assert_select "nav[aria-label=?]", "breadcrumb", false
    assert_no_match(/#{@note.folder.name}/, response.body)
  end

  test "show renders the stripped down public nav" do
    get public_note_path(username: @username, slug: @note.slug)

    assert_select "nav[data-topnav] a", "Flownote"
    assert_select "nav[data-topnav] button[data-controller=?]", "theme"
    assert_select "nav[data-topnav] a", { text: "Me", count: 0 }
  end

  test "md format serves the raw body" do
    get public_note_path(username: @username, slug: @note.slug, format: :md)

    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_equal @note.body, response.body
  end

  test "unpublished note is not found" do
    get public_note_path(username: @username, slug: "nosuchslug")

    assert_response :not_found
  end

  test "right slug under the wrong username is not found" do
    get public_note_path(username: "someoneelse", slug: @note.slug)

    assert_response :not_found
  end

  test "unpublishing takes the link down" do
    @note.unpublish!

    get public_note_path(username: @username, slug: "abc12345")

    assert_response :not_found
  end
end
