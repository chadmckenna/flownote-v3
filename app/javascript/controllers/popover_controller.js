import { Controller } from "@hotwired/stimulus"

// A popover menu: keyboard navigable, and closed once something in it is
// picked. A link that leaves the page takes the menu with it, but one that comes
// back to the same URL (Publish) is a morph, which keeps the element — and its
// open state — in place.
export default class extends Controller {
  // Also reached with the menu shut, when a hotkey clicks one of its links.
  hide() {
    if (this.element.matches(":popover-open")) this.element.hidePopover()
  }

  // ↑ ↓ (or j k) move through the items, wrapping at the ends; Home and End
  // jump to them. Enter picks an item and Esc closes the menu natively. Handled
  // here, ahead of scroll-keys on the document, so j/k don't scroll the note.
  navigate(event) {
    if (event.ctrlKey || event.altKey || event.metaKey) return

    const items = Array.from(this.element.querySelectorAll("[role=menuitem]"))
    const index = items.indexOf(document.activeElement)
    const next = {
      ArrowDown: index + 1, j: index + 1,
      ArrowUp: index - 1, k: index - 1,
      Home: 0, End: items.length - 1
    }[event.key]
    if (next === undefined) return

    event.preventDefault()
    items.at(next % items.length)?.focus()
  }
}
