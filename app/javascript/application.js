// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import "lexxy"
import "@rails/actiontext"

// An open <dialog> is part of the DOM Turbo snapshots on the way out, so a
// restore visit (the back button, Ctrl+Shift+[) would bring the modal back open
// with the page underneath it. Close them as the page is cached — every dialog
// in the app is transient chrome, so none of them should survive a visit.
document.addEventListener("turbo:before-cache", () => {
  document.querySelectorAll("dialog[open]").forEach((dialog) => dialog.close())
})

// Turbo Streams don't advance the URL on their own; this action lets the
// editor-layout stream response push the new path into history.
Turbo.StreamActions.advance_url = function () {
  const url = this.getAttribute("url")
  if (url) history.pushState({}, "", url)
}
