require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @root = folders(:root_one)
    @folder = folders(:work)
    @note = notes(:one)
    sign_in_as(@user)
  end

  test "new" do
    get new_folder_note_path(@folder)
    assert_response :success
  end

  test "create" do
    assert_difference("Note.count") do
      post folder_notes_path(@root), params: { note: { title: "New note", body: "Note body", folder_id: @root.id } }
    end

    note = Note.last
    assert_redirected_to edit_folder_note_path(note.folder, note)
  end

  test "create with missing title" do
    assert_no_difference("Note.count") do
      post folder_notes_path(@root), params: { note: { title: "", body: "Note body", folder_id: @root.id } }
    end

    assert_response :unprocessable_entity
  end

  test "show" do
    get folder_note_path(@folder, @note)
    assert_response :success
  end

  test "the app layout wires up the history shortcuts" do
    get folder_note_path(@folder, @note)

    assert_select "body[data-controller~=?]", "history"
    assert_select ".shortcuts-modal dt", "Back to the previous note"
  end

  test "show renders a wiki link to another note" do
    @note.update!(body: "See [[Root note]] and [[No such note]].")

    get folder_note_path(@folder, @note)

    assert_select "article.prose a[href=?]", folder_note_path(folders(:root_one), notes(:root_note))
    assert_select "article.prose .note-link--missing", "No such note"
  end

  test "the editor carries the user's own note titles for autocomplete" do
    get edit_folder_note_path(@folder, @note)

    completions = JSON.parse(css_select("[data-vim-editor-completions-value]").first["data-vim-editor-completions-value"])
    titles = completions.map { |completion| completion["label"] }

    assert_includes titles, notes(:root_note).title
    assert_not_includes titles, notes(:two).title
  end

  test "show renders the full editor shell (no content frame)" do
    get folder_note_path(@folder, @note)
    assert_response :success
    assert_select "main.folder-shell .folder-shell__sidebar"
    assert_select ".folder-shell__main"
    assert_select "turbo-frame#editor_main", false
  end

  test "show offers the share modal only once a note is published" do
    get folder_note_path(@folder, @note)
    assert_select "dialog.share-modal", false
    assert_select "a.share-toggle", "Publish"

    published = notes(:published)
    get folder_note_path(published.folder, published)
    assert_select "a.share-toggle", "Unpublish"
    assert_select "dialog.share-modal input.share-link__url[value=?]",
      public_note_url(username: @user.username, slug: published.slug)
  end

  test "show still renders when a published note's owner has no username" do
    published = notes(:published)
    @user.update_column(:username, nil)

    get folder_note_path(published.folder, published)

    assert_response :success
    assert_select "dialog.share-modal", false
  end

  test "edit offers the share modal for a published note" do
    published = notes(:published)

    get edit_folder_note_path(published.folder, published)

    assert_select "dialog.share-modal input.share-link__url"
  end

  test "edit keeps the publish and share controls in the form's action bar" do
    published = notes(:published)

    get edit_folder_note_path(published.folder, published)

    assert_select ".note-form__heading .btn-group a.share-toggle", "Unpublish"
    assert_select ".note-form__heading .btn-group button[data-share-open]"
    # A <form> inside the note form would be invalid HTML, and a dialog nested in
    # it would make Enter on the URL field save the note.
    assert_select "form.note-form form", false
    assert_select "form.note-form dialog", false
  end

  test "edit renders the per-note keyed editor" do
    get edit_folder_note_path(@folder, @note)
    assert_response :success
    assert_select "#note-editor-#{@note.id} textarea"
  end

  test "edit" do
    get edit_folder_note_path(@folder, @note)
    assert_response :success
  end

  test "update" do
    patch folder_note_path(@folder, @note), params: { note: { title: "Updated title" } }
    assert_redirected_to edit_folder_note_path(@note.folder, @note)
    assert_equal "Updated title", @note.reload.title
  end

  test "destroy note in subfolder redirects to folder" do
    assert_difference("Note.count", -1) do
      delete folder_note_path(@folder, @note)
    end

    assert_redirected_to folder_path(@folder)
  end

  test "destroy note in root folder redirects to root" do
    root_note = notes(:root_note)
    assert_difference("Note.count", -1) do
      delete folder_note_path(@root, root_note)
    end

    assert_redirected_to root_path
  end

  test "create note in folder" do
    assert_difference("Note.count") do
      post folder_notes_path(@folder), params: { note: { title: "Folder note", body: "Body", folder_id: @folder.id } }
    end
    assert_equal @folder, Note.last.folder
  end

  # Regression: note[folder_id] is mass-assignable, so a crafted request used to be
  # able to file an attacker-owned note into another user's folder.
  test "cannot create a note in another user's folder" do
    assert_no_difference "Note.count" do
      post folder_notes_path(@folder), params: {
        note: { title: "Planted", body: "x", folder_id: folders(:root_two).id }
      }
    end

    assert_response :unprocessable_entity
  end

  test "cannot move a note into another user's folder" do
    patch folder_note_path(@folder, @note), params: { note: { folder_id: folders(:root_two).id } }

    assert_response :unprocessable_entity
    assert_equal @folder, @note.reload.folder
  end

  # Defense in depth: even if a cross-user note already exists in the database,
  # nothing folder-scoped should surface or act on it.
  test "a pre-existing cross-user note is invisible to the folder's owner" do
    intruder = Note.new(title: "PLANTED", body: "x", user: users(:two), folder: @folder)
    intruder.save!(validate: false)

    sign_out
    sign_in_as(@user)

    get folder_path(@folder)
    assert_response :success
    assert_no_match(/PLANTED/, response.body)

    get folder_note_path(@folder, intruder)
    assert_response :not_found

    post folder_note_publication_path(@folder, intruder)
    assert_response :not_found
    assert_not_predicate intruder.reload, :published?
  end

  test "cannot access another user's note" do
    other_note = notes(:two)
    other_root = folders(:root_two)
    get folder_note_path(other_root, other_note)
    assert_response :not_found
  end

  test "requires authentication" do
    sign_out
    get folder_note_path(@folder, @note)
    assert_redirected_to new_session_path
  end
end
