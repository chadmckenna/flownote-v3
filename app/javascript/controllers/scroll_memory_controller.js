import { Controller } from "@hotwired/stimulus"

// Keeps an element's scroll position across Turbo visits. Opening a note is a
// cross-URL visit that replaces <body>, so the sidebar came back scrolled to the
// top and clicking a note far down the list lost your place in it. Positions are
// kept per key (the folder being listed), so each folder remembers its own.
// Same-URL morphs keep the element, and its scroll, without any help.
const positions = new Map()

export default class extends Controller {
  static values = { key: String }

  connect() {
    this.element.scrollTop = positions.get(this.keyValue) ?? 0
  }

  remember() {
    positions.set(this.keyValue, this.element.scrollTop)
  }
}
