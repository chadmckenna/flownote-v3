require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "show requires authentication" do
    sign_out

    get profile_path

    assert_redirected_to new_session_path
  end

  test "show" do
    get profile_path

    assert_response :success
    assert_select "h1", "Me"
  end

  test "update username" do
    patch profile_path, params: { current_password: "password", user: { username: "  NewName  " } }

    assert_redirected_to profile_path
    assert_equal "newname", @user.reload.username
  end

  test "update clears username when blank" do
    patch profile_path, params: { current_password: "password", user: { username: "" } }

    assert_redirected_to profile_path
    assert_nil @user.reload.username
  end

  test "update with a taken username" do
    users(:two).update!(username: "taken")

    patch profile_path, params: { current_password: "password", user: { username: "taken" } }

    assert_response :unprocessable_entity
    assert_equal "userone", @user.reload.username
  end

  test "update with an invalid username" do
    patch profile_path, params: { current_password: "password", user: { username: "no spaces!" } }

    assert_response :unprocessable_entity
    assert_equal "userone", @user.reload.username
  end

  test "update with the wrong current password" do
    patch profile_path, params: { current_password: "wrong", user: { username: "changed" } }

    assert_redirected_to profile_path
    assert_equal "userone", @user.reload.username
  end

  test "update_password" do
    other_session = @user.sessions.create!

    patch profile_password_path, params: {
      current_password: "password", user: { password: "new-password", password_confirmation: "new-password" }
    }

    assert_redirected_to profile_path
    assert @user.reload.authenticate("new-password")
    assert_not Session.exists?(other_session.id)

    follow_redirect!
    assert_response :success
  end

  test "update_password with a mismatched confirmation" do
    patch profile_password_path, params: {
      current_password: "password", user: { password: "new-password", password_confirmation: "nope" }
    }

    assert_response :unprocessable_entity
    assert @user.reload.authenticate("password")
  end

  test "update_password with the wrong current password" do
    patch profile_password_path, params: {
      current_password: "wrong", user: { password: "new-password", password_confirmation: "new-password" }
    }

    assert_redirected_to profile_path
    assert @user.reload.authenticate("password")
  end

  test "destroy" do
    assert_difference "User.count", -1 do
      delete profile_path, params: { current_password: "password" }
    end

    assert_empty Folder.where(user_id: @user.id)
    assert_empty Note.where(user_id: @user.id)
    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "destroy with the wrong current password" do
    assert_no_difference "User.count" do
      delete profile_path, params: { current_password: "wrong" }
    end

    assert_redirected_to profile_path
  end
end
