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

  test "show renders the full editor shell (no content frame)" do
    get folder_note_path(@folder, @note)
    assert_response :success
    assert_select "main.folder-shell .folder-shell__sidebar"
    assert_select ".folder-shell__main"
    assert_select "turbo-frame#editor_main", false
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
