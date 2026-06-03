import { Controller } from "@hotwired/stimulus"

// Turns a keypress into a click (or focus) on this controller's element, so a
// hotkey can live right next to the button/link it triggers. No central keymap:
// each binding is declared in the view via Stimulus's keyboard event filters,
// scoped to the document so the key works anywhere on the page. e.g.
//
//   <%= link_to "New note", new_note_path,
//         data: { controller: "hotkey", action: "keydown.c@document->hotkey#click" } %>
//
// For cross-platform chords, bind both modifiers in one action string:
//   "keydown.meta+k@document->hotkey#focus keydown.ctrl+k@document->hotkey#focus"
//
// Keypresses are ignored while the user is typing in a field or editor, when
// another handler already handled the event, or when the element is hidden.
export default class extends Controller {
  click(event) {
    if (this.#isClickable && !this.#shouldIgnore(event)) {
      event.preventDefault()
      this.element.click()
    }
  }

  focus(event) {
    if (this.#isClickable && !this.#shouldIgnore(event)) {
      event.preventDefault()
      this.element.focus()
    }
  }

  #shouldIgnore(event) {
    return event.defaultPrevented ||
      event.target.closest("input, textarea, [contenteditable], .cm-editor")
  }

  get #isClickable() {
    return getComputedStyle(this.element).pointerEvents !== "none"
  }
}
