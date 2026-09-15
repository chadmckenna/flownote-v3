import { Controller } from "@hotwired/stimulus"

// Vim's jump list, applied to the app: Ctrl+O steps back through the notes and
// folders you've visited, Ctrl+I forward. Every navigation here is a Turbo Drive
// visit, so the browser's own history already holds the trail — and Turbo
// restores each page, scroll position included, on the way back.
//
// Matched on event.code so it works on any keyboard layout, and stood down while
// the cursor is in the editor or a field: Ctrl-O there is vim's own "run one
// normal-mode command" and Ctrl-I is Tab.
export default class extends Controller {
  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    if (!event.ctrlKey || event.altKey || event.metaKey || event.shiftKey) return
    if (event.defaultPrevented || this.#isTyping(event)) return

    if (event.code === "KeyO") {
      event.preventDefault()
      window.history.back()
    } else if (event.code === "KeyI") {
      event.preventDefault()
      window.history.forward()
    }
  }

  #isTyping(event) {
    return event.target.closest("input, textarea, [contenteditable], .cm-editor")
  }
}
