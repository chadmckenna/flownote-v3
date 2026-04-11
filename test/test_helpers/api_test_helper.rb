module ApiTestHelper
  def create_oauth_application(name: "Test App", confidential: false)
    Doorkeeper::Application.create!(
      name: name,
      redirect_uri: "http://127.0.0.1:19876/callback",
      confidential: confidential
    )
  end

  def create_access_token(user:, application: nil, scopes: "read write")
    application ||= create_oauth_application
    Doorkeeper::AccessToken.create!(
      application: application,
      resource_owner_id: user.id,
      scopes: scopes
    )
  end

  def api_headers(token)
    { "Authorization" => "Bearer #{token.token}" }
  end
end
