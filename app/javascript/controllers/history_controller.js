import { Controller } from "@hotwired/stimulus"

// Vim's jump list, applied to the app: Ctrl+Shift+[ steps back through the notes
// and folders you've visited, Ctrl+Shift+] forward. Every navigation here is a
// Turbo Drive visit, so the browser's own history already holds the trail — and
// Turbo restores each page, scroll position included, on the way back.
//
// Ctrl+Shift+* is the app's global chord: vim claims none of them, so unlike a
// bare Ctrl+O these keep working with the cursor in the editor. Matched on
// event.code, i.e. the physical key next to P on a US layout — which is where
// the bracket keys are for this app's users, but is a different character on
// layouts that put brackets elsewhere.
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
      this.#jump(() => window.history.back())
    } else if (event.code === "BracketRight") {
      event.preventDefault()
      this.#jump(() => window.history.forward())
    }
  }

  // A history jump is a Turbo *restoration* visit: it never fires
  // turbo:before-visit, which is the only hook the editor's unsaved-changes
  // guard has, and beforeunload doesn't fire for same-document navigation
  // either. So the editor publishes [data-unsaved] and the prompt happens here
  // — otherwise this chord would be the one exit that discards your typing.
  #jump(go) {
    if (document.querySelector("[data-unsaved]") && !this.#confirmDiscard()) return
    go()
  }

  #confirmDiscard() {
    return confirm("You have unsaved changes. Leave without saving?")
  }
}
