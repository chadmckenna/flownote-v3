require "test_helper"

class Notes::TitlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @folder = folders(:work)
    @note = notes(:one)
    sign_in_as(@user)
  end

  test "edit renders the rename form into the note's sidebar row" do
    get edit_folder_note_title_path(@folder, @note)

    assert_response :success
    assert_select "turbo-frame#title_note_#{@note.id} input[name='note[title]'][value=?]", @note.title
    assert_select "input[name='note[title]'][data-action=?]", "focus->caret#end"
  end

  test "update renames the note and returns to where it was renamed from" do
    patch folder_note_title_path(@folder, @note), params: { note: { title: "Renamed" } },
      headers: { "HTTP_REFERER" => folder_url(@folder) }

    assert_redirected_to folder_url(@folder)
    assert_equal "Renamed", @note.reload.title
  end

  test "update changes nothing but the title" do
    patch folder_note_title_path(@folder, @note), params: { note: { title: "Renamed", body: "Overwritten" } }

    assert_equal "Body of the first note", @note.reload.body
  end

  test "update with a blank title keeps the old one and says why" do
    patch folder_note_title_path(@folder, @note), params: { note: { title: "" } }

    assert_redirected_to edit_folder_note_path(@folder, @note)
    assert_equal "First note", @note.reload.title
    assert_match "Title", flash[:alert]
  end

  test "cannot rename another user's note" do
    patch folder_note_title_path(folders(:root_two), notes(:two)), params: { note: { title: "Hijacked" } }

    assert_response :not_found
  end
end
