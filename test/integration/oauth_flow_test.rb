require "test_helper"

class OAuthFlowTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @user = users(:one)
    @app = create_oauth_application(name: "Flownote CLI")
  end

  test "full PKCE authorization code flow" do
    # Step 1: Generate PKCE code_verifier and code_challenge
    code_verifier = SecureRandom.urlsafe_base64(32)
    code_challenge = Base64.urlsafe_encode64(
      Digest::SHA256.digest(code_verifier), padding: false
    )

    # Step 2: Sign in the user (simulating browser session)
    sign_in_as(@user)

    # Step 3: Request authorization
    get "/oauth/authorize", params: {
      client_id: @app.uid,
      redirect_uri: @app.redirect_uri,
      response_type: "code",
      scope: "read write",
      code_challenge: code_challenge,
      code_challenge_method: "S256"
    }

    # Since skip_authorization is set for "Flownote CLI", we get redirected
    # directly with the authorization code
    assert_response :redirect
    callback_uri = URI.parse(response.location)
    assert_equal "127.0.0.1", callback_uri.host
    authorization_code = Rack::Utils.parse_query(callback_uri.query)["code"]
    assert_not_nil authorization_code

    # Step 4: Exchange authorization code for access token
    post "/oauth/token", params: {
      grant_type: "authorization_code",
      code: authorization_code,
      client_id: @app.uid,
      redirect_uri: @app.redirect_uri,
      code_verifier: code_verifier
    }

    assert_response :success
    token_response = JSON.parse(response.body)
    assert_not_nil token_response["access_token"]
    assert_equal "read write", token_response["scope"]
    assert_equal "Bearer", token_response["token_type"]

    # Step 5: Use token to access API
    get api_v1_me_path, headers: {
      "Authorization" => "Bearer #{token_response['access_token']}"
    }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @user.id, json["id"]
    assert_equal @user.email_address, json["email"]
  end

  test "authorization requires authentication" do
    get "/oauth/authorize", params: {
      client_id: @app.uid,
      redirect_uri: @app.redirect_uri,
      response_type: "code",
      scope: "read"
    }

    assert_redirected_to new_session_path
  end

  test "token exchange fails without code_verifier when PKCE required" do
    sign_in_as(@user)

    code_verifier = SecureRandom.urlsafe_base64(32)
    code_challenge = Base64.urlsafe_encode64(
      Digest::SHA256.digest(code_verifier), padding: false
    )

    get "/oauth/authorize", params: {
      client_id: @app.uid,
      redirect_uri: @app.redirect_uri,
      response_type: "code",
      scope: "read",
      code_challenge: code_challenge,
      code_challenge_method: "S256"
    }

    callback_uri = URI.parse(response.location)
    authorization_code = Rack::Utils.parse_query(callback_uri.query)["code"]

    # Try to exchange without code_verifier — should fail
    post "/oauth/token", params: {
      grant_type: "authorization_code",
      code: authorization_code,
      client_id: @app.uid,
      redirect_uri: @app.redirect_uri
    }

    assert_response :bad_request
  end
end
