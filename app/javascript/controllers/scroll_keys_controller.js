import { Controller } from "@hotwired/stimulus"

// Keyboard scrolling for the note pane. The pane, not the document, is what
// overflows (.folder-shell__main is overflow: hidden), and a browser scrolls the
// scrollable ancestor of whatever has focus — with focus on <body> that's the
// document, which never overflows, so arrows and Page Up/Down did nothing.
//
// Handled on the document like the app's other global keys, rather than by
// making the pane focusable: nothing has to be clicked or focused first, and the
// keys behave the same however you arrived at the page.
export default class extends Controller {
  static values = { line: { type: Number, default: 64 } }

  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    if (event.ctrlKey || event.altKey || event.metaKey) return
    if (event.defaultPrevented || this.#isTyping(event) || this.#dialogOpen) return

    const amount = this.#amountFor(event)
    if (amount === undefined) return

    event.preventDefault()
    this.element.scrollBy({ top: amount })
  }

  #amountFor(event) {
    // A page keeps a couple of lines of overlap, the way a browser's own Page
    // Down does, so you don't lose your place across a jump.
    const page = this.element.clientHeight - this.lineValue

    switch (event.key) {
      case "ArrowDown": case "j": return this.lineValue
      case "ArrowUp": case "k": return -this.lineValue
      case "PageDown": return page
      case "PageUp": return -page
      case "Home": return -this.element.scrollHeight
      case "End": return this.element.scrollHeight
    }
  }

  #isTyping(event) {
    return event.target.closest("input, textarea, [contenteditable], .cm-editor")
  }

  // A modal owns the keyboard while it's up — arrows move through its results.
  get #dialogOpen() {
    return document.querySelector("dialog[open]") !== null
  }
}
