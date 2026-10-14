require "test_helper"

class PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "update saves where sidebar notes open" do
    patch preferences_path, params: { user: { open_notes_in: "view" } }

    assert_redirected_to profile_path
    assert_equal "view", @user.reload.open_notes_in
  end

  test "update rejects an unknown value" do
    patch preferences_path, params: { user: { open_notes_in: "split" } }

    assert_redirected_to profile_path
    assert_equal "edit", @user.reload.open_notes_in
  end

  test "requires sign in" do
    sign_out
    patch preferences_path, params: { user: { open_notes_in: "view" } }

    assert_redirected_to new_session_path
  end
end
