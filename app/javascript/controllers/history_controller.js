import { Controller } from "@hotwired/stimulus"

// Vim's jump list, applied to the app: Ctrl+Shift+[ steps back through the notes
// and folders you've visited, Ctrl+Shift+] forward. Every navigation here is a
// Turbo Drive visit, so the browser's own history already holds the trail — and
// Turbo restores each page, scroll position included, on the way back.
//
// Ctrl+Shift+* is the app's global chord: vim claims none of them, so unlike a
// bare Ctrl+O these keep working with the cursor in the editor. Matched on
// event.code so the binding doesn't depend on keyboard layout.
export default class extends Controller {
  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    if (!event.ctrlKey || !event.shiftKey || event.altKey || event.metaKey) return

    if (event.code === "BracketLeft") {
      event.preventDefault()
      window.history.back()
    } else if (event.code === "BracketRight") {
      event.preventDefault()
      window.history.forward()
    }
  }
}
