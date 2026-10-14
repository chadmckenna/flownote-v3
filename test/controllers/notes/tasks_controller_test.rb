require "test_helper"

class Notes::TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @folder = folders(:work)
    @note = notes(:one)
    @note.update!(body: "To do\n\n- [ ] milk\n- [x] eggs\n")
    sign_in_as(@user)
  end

  test "update checks a task" do
    patch folder_note_task_path(@folder, @note, line: 3), params: { checked: "true" }

    assert_response :no_content
    assert_equal "To do\n\n- [x] milk\n- [x] eggs\n", @note.reload.body
  end

  test "update unchecks a task" do
    patch folder_note_task_path(@folder, @note, line: 4), params: { checked: "false" }

    assert_response :no_content
    assert_equal "To do\n\n- [ ] milk\n- [ ] eggs\n", @note.reload.body
  end

  test "update conflicts when the line is no longer a task" do
    patch folder_note_task_path(@folder, @note, line: 1), params: { checked: "true" }

    assert_response :conflict
    assert_equal "To do\n\n- [ ] milk\n- [x] eggs\n", @note.reload.body
  end

  test "cannot check a task in another user's note" do
    patch folder_note_task_path(folders(:root_two), notes(:two), line: 1), params: { checked: "true" }

    assert_response :not_found
  end
end
