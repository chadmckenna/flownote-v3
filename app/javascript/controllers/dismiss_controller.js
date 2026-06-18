import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Cancels an inline frame form (new note/folder, edit folder) without navigating
// away. These forms live in frames defined in the layout (sidebar/context), so
// reloading the frame from the current URL fails with "Content missing" — a
// Turbo-Frame request gets the minimal frame layout, whose yield is the main pane,
// not the frame. Instead we refresh the current page: a same-URL visit morphs
// (turbo-refresh-method=morph), restoring the breadcrumb and the empty new-form
// frames from the server while the open note's editor is preserved by its
// before-morph-element guard. The URL and main pane stay put.
export default class extends Controller {
  cancel(event) {
    event.preventDefault()
    Turbo.visit(window.location.href, { action: "replace" })
  }
}
