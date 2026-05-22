// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import "lexxy"
import "@rails/actiontext"

// Turbo Streams don't advance the URL on their own; this action lets the
// editor-layout stream response push the new path into history.
Turbo.StreamActions.advance_url = function () {
  const url = this.getAttribute("url")
  if (url) history.pushState({}, "", url)
}
