import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Ticks a note's Markdown tasks from its view page. Each live checkbox names
// the source line it was rendered from (ApplicationHelper#checkable_tasks); a
// change PATCHes that line's new state, and the box has already moved, so
// success needs nothing more.
//
// Turbo.fetch tags the request so this tab ignores the refresh broadcast its
// own save sets off — a second quick tick isn't morphed back mid-flight — while
// any other tab on the note still refreshes.
export default class extends Controller {
  static values = { url: String }

  async toggle(event) {
    const box = event.target
    const body = new FormData()
    body.append("checked", box.checked)

    const response = await Turbo.fetch(this.urlValue.replace(":line", box.dataset.line), {
      method: "PATCH",
      headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
      body
    }).catch(() => null)

    // Out of date (that line isn't a task any more) or offline: put the box
    // back and show the note as it now stands.
    if (!response?.ok) {
      box.checked = !box.checked
      Turbo.visit(window.location.href, { action: "replace" })
    }
  }
}
