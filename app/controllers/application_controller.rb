class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Publicly shared pages opt out: recipients don't choose their browser, and those
  # pages are read-only HTML that needs none of the gated features. allow_browser
  # registers an anonymous lambda, so `unless:` is the only way to exempt a controller.
  allow_browser versions: :modern, unless: :public_page?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :folder_shell?

  private
    # Overridden by controllers serving pages to anonymous visitors.
    def public_page?
      false
    end

    # True once a request has loaded the folder browsing/editing shell (see ShellLoader),
    # which tells the application layout to render the folder-shell instead of a plain container.
    def folder_shell?
      @folder_shell.present?
    end
end
