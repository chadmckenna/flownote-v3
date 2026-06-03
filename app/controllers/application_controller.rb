class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :folder_shell?

  private
    # True once a request has loaded the folder browsing/editing shell (see ShellLoader),
    # which tells the application layout to render the folder-shell instead of a plain container.
    def folder_shell?
      @folder_shell.present?
    end
end
