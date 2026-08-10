require "test_helper"

class Notes::PublicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @folder = folders(:work)
    @note = notes(:one)
    sign_in_as(@user)
  end

  test "create publishes the note" do
    post folder_note_publication_path(@folder, @note)

    assert_redirected_to folder_note_path(@folder, @note)
    assert_predicate @note.reload, :published?
  end

  test "create redirects back to where the toggle was clicked" do
    post folder_note_publication_path(@folder, @note),
      headers: { "HTTP_REFERER" => edit_folder_note_url(@folder, @note) }

    assert_redirected_to edit_folder_note_url(@folder, @note)
  end

  # Sends a referer because a real browser always does, and redirect_back_or_to
  # would silently bounce back to the note instead of the profile.
  test "create requires a username" do
    sign_out
    sign_in_as(users(:two))
    note = notes(:two)

    post folder_note_publication_path(folders(:root_two), note),
      headers: { "HTTP_REFERER" => folder_note_url(folders(:root_two), note) }

    assert_redirected_to profile_path
    assert_not_predicate note.reload, :published?
  end

  test "destroy unpublishes the note" do
    note = notes(:published)

    delete folder_note_publication_path(note.folder, note)

    assert_redirected_to folder_note_path(note.folder, note)
    assert_nil note.reload.slug
  end

  test "cannot publish another user's note" do
    post folder_note_publication_path(folders(:root_two), notes(:two))

    assert_response :not_found
  end

  test "requires authentication" do
    sign_out

    post folder_note_publication_path(@folder, @note)

    assert_redirected_to new_session_path
  end
end
