require "test_helper"

class Api::V1::MeControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @token = create_access_token(user: @user)
  end

  test "show with valid token returns user" do
    get api_v1_me_path, headers: api_headers(@token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @user.id, json["id"]
    assert_equal @user.email_address, json["email"]
  end

  test "show without token returns 401" do
    get api_v1_me_path

    assert_response :unauthorized
  end

  test "show with expired token returns 401" do
    @token.update!(expires_in: 0, created_at: 1.day.ago)

    get api_v1_me_path, headers: api_headers(@token)

    assert_response :unauthorized
  end

  test "show with insufficient scope returns 403" do
    token = create_access_token(user: @user, scopes: "")

    get api_v1_me_path, headers: api_headers(token)

    assert_response :forbidden
  end
end
