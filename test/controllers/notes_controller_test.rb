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

  test "create with a title the folder already has" do
    assert_no_difference("Note.count") do
      post folder_notes_path(@folder), params: { note: { title: @note.title, body: "Note body", folder_id: @folder.id } }
    end

    assert_response :unprocessable_entity
    assert_select ".alert--error", /already exists in this folder/
  end

  test "show" do
    get folder_note_path(@folder, @note)
    assert_response :success
  end

  test "the app layout wires up the history shortcuts" do
    get folder_note_path(@folder, @note)

    assert_select "body[data-controller~=?]", "history"
    assert_select ".shortcuts-modal dt", "Back / forward"
  end

  test "the shortcuts list names the Ctrl+Shift chord once and lists each key under it" do
    get folder_note_path(@folder, @note)

    assert_select ".shortcuts-modal h3", "Ctrl + Shift +"
    assert_select ".shortcuts-modal kbd", text: "Ctrl", count: 0
    assert_select ".shortcuts-modal__row", text: /Note menu.*M/m
  end

  test "show renders a wiki link to another note" do
    @note.update!(body: "See [[Root note]] and [[No such note]].")

    get folder_note_path(@folder, @note)

    assert_select "article.prose a[href=?]", folder_note_path(folders(:root_one), notes(:root_note))
    assert_select "article.prose .note-link--missing", "No such note"
  end

  test "the editor carries the user's own note titles for autocomplete" do
    get edit_folder_note_path(@folder, @note)

    titles = completions.map { |completion| completion["label"] }

    assert_includes titles, notes(:root_note).title
    assert_not_includes titles, notes(:two).title
  end

  test "the editor's autocomplete inserts an absolute path" do
    get edit_folder_note_path(@folder, @note)

    applied = completions.to_h { |completion| [ completion["label"], completion["apply"] ] }

    assert_equal "~/Root note", applied[notes(:root_note).title]
    assert_equal "~/Work/First note", applied[notes(:one).title]
    assert_equal "~/Work/Projects/Shared note", applied[notes(:published).title]
  end

  test "the autocomplete offers folders, each with a trailing slash" do
    get edit_folder_note_path(@folder, @note)

    applied = completions.to_h { |completion| [ completion["label"], completion["apply"] ] }

    assert_equal "~/", applied["~/"]
    assert_equal "~/Work/", applied["Work/"]
    assert_equal "~/Work/Projects/", applied["Projects/"]
    assert_not_includes applied.keys, "#{folders(:other_user_folder).name}/"
  end

  # What the dropdown inserts has to be a target the resolver reads back as the
  # very thing you picked — from anywhere in the tree, since an absolute path is
  # the whole point of inserting one.
  test "every autocomplete entry round-trips through the link resolver" do
    get edit_folder_note_path(@folder, @note)

    entries = completions
    resolved = Notes::LinkResolver.new(user: @user, from: notes(:published)).resolve(entries.map { |e| e["apply"] })

    assert_not_empty entries
    entries.each do |entry|
      record = resolved[entry["apply"]]
      assert_not_nil record, "#{entry["apply"]} resolved to nothing"

      name = if record.is_a?(Folder)
        record.root? ? "~/" : "#{record.name}/"
      else
        record.title
      end

      assert_equal entry["label"], name, "#{entry["apply"]} did not resolve back"
    end
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
    assert_select "#note-actions a", "Publish"

    published = notes(:published)
    get folder_note_path(published.folder, published)
    assert_select "#note-actions a", "Unpublish"
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

  test "the note bar keeps Edit in reach and the rest in its actions menu" do
    get folder_note_path(@folder, @note)

    assert_select ".note-bar > a", "Edit"
    assert_select ".note-bar button[popovertarget=note-actions]"
    assert_select "#note-actions[popover][role=menu][data-action~=?]", "keydown->popover#navigate"
    assert_select "#note-actions[popover]" do
      assert_select "a", "Publish"
      assert_select "a[href=?]", folder_path(@folder), text: "Close"
      assert_select "a[data-turbo-method=delete]", "Delete"
    end
  end

  test "edit keeps View and Save in the bar and the rest in a menu inside the form" do
    published = notes(:published)

    get edit_folder_note_path(published.folder, published)

    assert_select "form.note-form .note-bar > a", "View"
    assert_select "form.note-form .note-bar input[type=submit][value=Save]"
    assert_select "form.note-form #note-actions" do
      assert_select "a", "Unpublish"
      assert_select "button[data-share-open]"
      assert_select "a[data-turbo-method=delete]", "Delete"
    end
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

  test "Ctrl+Shift+I or L jumps into the editor, as it opens it from view mode" do
    get edit_folder_note_path(@folder, @note)
    %w[i l].each do |key|
      assert_select "#note-editor-#{@note.id}[data-action~=?]", "keydown.shift+ctrl+#{key}@window->vim-editor#focus:capture"
    end

    get folder_note_path(@folder, @note)
    %w[i l].each do |key|
      assert_select ".note-bar a[data-action*=?]", "keydown.shift+ctrl+#{key}@document->hotkey#click", text: "Edit"
    end
  end

  test "Ctrl+Shift+H focuses the sidebar" do
    get edit_folder_note_path(@folder, @note)
    assert_select ".folder-shell__sidebar[data-action~=?]", "keydown.shift+ctrl+h@window->sidebar-keys#focus:capture"
  end

  test "edit" do
    get edit_folder_note_path(@folder, @note)
    assert_response :success
  end

  test "edit shows the filename, not a title field: notes are renamed from the sidebar" do
    get edit_folder_note_path(@folder, @note)

    assert_select ".note-filename", text: "#{@note.title}.md"
    assert_select ".note-form input[name='note[title]']", false
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

  test "destroy from another page stays on it: the sidebar can delete a note you're not on" do
    other = notes(:root_note)
    delete folder_note_path(@folder, @note), headers: { "HTTP_REFERER" => edit_folder_note_url(@root, other) }

    assert_redirected_to edit_folder_note_url(@root, other)
  end

  test "destroy of the note you're on goes to its folder" do
    delete folder_note_path(@folder, @note), headers: { "HTTP_REFERER" => edit_folder_note_url(@folder, @note) }
    assert_redirected_to folder_path(@folder)

    note = notes(:root_note)
    delete folder_note_path(@root, note), headers: { "HTTP_REFERER" => folder_note_url(@root, note) }
    assert_redirected_to root_path
  end

  test "the sidebar carries a delete form for each note, for d" do
    get folder_path(@folder)

    assert_select ".folder-shell__sidebar li form[hidden][action=?]", folder_note_path(@folder, @note)
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

  private
    def completions
      JSON.parse(css_select("[data-vim-editor-completions-value]").first["data-vim-editor-completions-value"])
    end
end
