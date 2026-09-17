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

  # Requirement: a share page must never link to another note — not even for the
  # author, whose Current.user is set while they view their own public page. The
  # link renders unresolved, so a reader sees that the author meant to link
  # something without learning that it exists or where it lives.
  test "wiki links render unresolved on a public page" do
    @note.update!(body: "#{@note.body}\n\n[[First note]]")

    [ nil, users(:one), users(:two) ].each do |viewer|
      viewer ? sign_in_as(viewer) : sign_out

      get public_note_path(username: @username, slug: @note.slug)

      assert_response :success
      assert_select ".prose a[data-note-link]", false
      assert_select ".prose a[href^=?]", "/folders", false
      assert_select ".prose .note-link--missing", "First note"
      assert_no_match(/#{notes(:one).folder.name}/, response.body)
    end
  end

  # A folder link would name a folder, which a share page must never disclose.
  test "folder links render unresolved on a public page" do
    @note.update!(body: "#{@note.body}\n\n[[Work/]] and [[~/]]")

    [ nil, users(:one), users(:two) ].each do |viewer|
      viewer ? sign_in_as(viewer) : sign_out

      get public_note_path(username: @username, slug: @note.slug)

      assert_response :success
      assert_select ".prose a[data-note-link]", false
      assert_select ".prose a[href^=?]", "/folders", false
      assert_select ".prose .note-link--missing", 2
    end
  end

  # Whatever the author typed is all a reader gets — no lookup means nothing to
  # disclose even when the target names a note that really is there.
  test "a public page runs no note or folder lookup" do
    @note.update!(body: "#{@note.body}\n\n[[First note]] [[Work/]]")
    sign_out

    get public_note_path(username: @username, slug: @note.slug)

    assert_response :success
    assert_queries_count 0 do
      get public_note_path(username: @username, slug: @note.slug)
    end
  end

  test "the markdown format leaves wiki links untouched" do
    @note.update!(body: "#{@note.body}\n\n[[First note]]")

    get public_note_path(username: @username, slug: @note.slug, format: :md)

    assert_equal @note.body, response.body
  end

  test "a dead link renders the not-available page, not a bare 404" do
    get public_note_path(username: @username, slug: "nosuchslug")

    assert_response :not_found
    assert_select "h1", "This note isn't available"
    assert_select "a", "Go to Flownote"
  end

  test "a dead link in md format answers with markdown, not html" do
    get public_note_path(username: @username, slug: "nosuchslug", format: :md)

    assert_response :not_found
    assert_equal "text/markdown", response.media_type
    assert_match(/isn't available/, response.body)
  end

  test "the not-available page does not disclose whether the note ever existed" do
    dead_slug = @note.slug
    @note.unpublish!

    get public_note_path(username: @username, slug: dead_slug)
    unpublished = response.body

    get public_note_path(username: @username, slug: "nosuchslug")

    assert_equal unpublished, response.body
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
