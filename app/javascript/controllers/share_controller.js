import { Controller } from "@hotwired/stimulus"

// Keeps the note action bar compact: a small share button opens the public link
// in a modal instead of parking a URL field in the bar. Open/close mirrors
// search_controller and shortcuts_controller.
export default class extends Controller {
  static targets = [ "dialog", "url" ]

  open() {
    if (this.dialogTarget.open) return

    this.dialogTarget.showModal()
    this.urlTarget.focus()
    this.urlTarget.select()
  }

  close() {
    this.dialogTarget.close()
  }

  // Native <dialog> centers its content; clicks that land on the element itself
  // (rather than a child) are backdrop clicks.
  backdropClose(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
