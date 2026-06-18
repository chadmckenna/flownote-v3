import { Controller } from "@hotwired/stimulus"

// Keyboard-shortcut help modal. Opens from anywhere on Ctrl+Shift+K and shows a
// static list of the app's shortcuts. Mirrors search_controller's open/close
// handling. Matched on event.code ("KeyK"), not event.key, so it's layout- and
// Shift-independent.
export default class extends Controller {
  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    if (event.ctrlKey && event.shiftKey && event.code === "KeyK") {
      event.preventDefault()
      this.open()
    }
  }

  open() {
    if (!this.element.open) this.element.showModal()
  }

  close() {
    this.element.close()
  }

  backdropClose(event) {
    if (event.target === this.element) this.close()
  }
}
