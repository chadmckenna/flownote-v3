# frozen_string_literal: true

Doorkeeper.configure do
  orm :active_record

  # Use Rails 8's session-based auth to identify the resource owner.
  # Doorkeeper's authorization endpoint inherits from ApplicationController
  # (via base_controller below), so the Authentication concern is active.
  resource_owner_authenticator do
    Current.user || redirect_to(new_session_path)
  end

  # Doorkeeper controllers inherit from ApplicationController so that
  # /oauth/authorize gets session-based authentication. Doorkeeper's
  # TokensController already skips verify_authenticity_token internally.
  base_controller "ApplicationController"

  # Only authorization code flow (no implicit, password, or client_credentials)
  grant_flows %w[authorization_code]

  # Require PKCE for all authorization code grants (CLI is a public client)
  force_pkce

  # Token expiration
  access_token_expires_in 30.days

  # Scopes
  default_scopes :read
  optional_scopes :write

  # Auto-approve the first-party CLI app (skip the consent screen).
  # Public clients (non-confidential) are first-party apps that don't need consent.
  skip_authorization do |_resource_owner, client|
    !client.application.confidential?
  end

  # Don't allow SSL enforcement in development for localhost redirect URIs
  force_ssl_in_redirect_uri { |uri| !Rails.env.local? && uri.host != "127.0.0.1" }
end
