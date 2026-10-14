import { Controller } from "@hotwired/stimulus"

// Puts the caret at the end of a field when it takes focus, so a rename starts
// where you'd add to the name, as nvim-tree's does. Focus given by script —
// Turbo's autofocus when a rename form loads — leaves it at the start.
export default class extends Controller {
  end() {
    const length = this.element.value.length
    this.element.setSelectionRange(length, length)
  }
}
