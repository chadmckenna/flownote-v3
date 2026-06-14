import { Controller } from "@hotwired/stimulus"

// Spotlight-style search modal. Opens from anywhere on Ctrl+Shift+\, focuses the
// input, and submits the form (debounced) on every keystroke so results stream
// into the search_results Turbo Frame. Results are rendered server-side — this
// controller only handles open/close and the debounced submit.
//
// The shortcut is matched on event.code ("Backslash"), not event.key, because
// Shift rewrites "\" to "|" in event.key on most layouts.
export default class extends Controller {
  static targets = ["form", "input"]
  static values = { debounce: { type: Number, default: 150 } }

  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    clearTimeout(this.timeout)
  }

  onKeydown(event) {
    if (event.ctrlKey && event.shiftKey && event.code === "Backslash") {
      event.preventDefault()
      this.open()
    }
  }

  open() {
    if (this.element.open) return
    this.element.showModal()
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  close() {
    this.element.close()
  }

  // Native <dialog> centers its content; clicks that land on the element itself
  // (rather than a child) are backdrop clicks.
  backdropClose(event) {
    if (event.target === this.element) this.close()
  }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.formTarget.requestSubmit(), this.debounceValue)
  }

  // Arrow-key navigation moves real focus between the input and the result
  // links, so Enter activates the focused link with no extra handling.
  next(event) {
    const links = this.links
    if (links.length === 0) return
    event.preventDefault()
    const index = links.indexOf(document.activeElement)
    ;(links[index + 1] || links[0]).focus()
  }

  prev(event) {
    const links = this.links
    if (links.length === 0) return
    event.preventDefault()
    const index = links.indexOf(document.activeElement)
    if (index <= 0) {
      this.inputTarget.focus()
    } else {
      links[index - 1].focus()
    }
  }

  get links() {
    return Array.from(this.element.querySelectorAll(".file-listing a"))
  }
}
