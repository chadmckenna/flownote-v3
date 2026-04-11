require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "create with valid params" do
    assert_difference "User.count", 1 do
      post registration_path, params: { user: {
        email_address: "new@example.com",
        password: "password",
        password_confirmation: "password"
      } }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with duplicate email" do
    assert_no_difference "User.count" do
      post registration_path, params: { user: {
        email_address: "one@example.com",
        password: "password",
        password_confirmation: "password"
      } }
    end

    assert_response :unprocessable_entity
  end

  test "create with mismatched password confirmation" do
    assert_no_difference "User.count" do
      post registration_path, params: { user: {
        email_address: "new@example.com",
        password: "password",
        password_confirmation: "different"
      } }
    end

    assert_response :unprocessable_entity
  end

  test "create with blank password" do
    assert_no_difference "User.count" do
      post registration_path, params: { user: {
        email_address: "new@example.com",
        password: "",
        password_confirmation: ""
      } }
    end

    assert_response :unprocessable_entity
  end
end
