import { Controller } from "@hotwired/stimulus"

// Scrolls the pane to a #fragment target. Turbo already does this — but against
// the window, and the pane is what overflows (.folder-shell__main is overflow:
// hidden), so the scroll only survives while that pane does.
//
// A visit to a page Turbo has cached renders twice: the cached snapshot first,
// then the fresh response. Turbo scrolls to the anchor after the first render
// and the second throws that pane away, so the link appeared to work and then
// snapped back to the top. Only pages you had already visited were affected,
// which is what put them in the snapshot cache.
//
// Reapplying it on connect covers it: every render brings a new pane and a new
// controller with it, so the last render scrolls last.
export default class extends Controller {
  connect() {
    this.#scrollToAnchor()
  }

  #scrollToAnchor() {
    const anchor = this.#anchor
    if (!anchor) return

    const target = this.element.querySelector(`[id="${anchor}"], a[name="${anchor}"]`)
    target?.scrollIntoView()
  }

  // The hash is percent-encoded in the URL but not in the id it names, and it is
  // interpolated into a selector, so anything that isn't a plain fragment is
  // escaped rather than trusted.
  get #anchor() {
    const hash = window.location.hash.slice(1)
    if (!hash) return null

    try {
      return CSS.escape(decodeURIComponent(hash))
    } catch {
      return CSS.escape(hash)
    }
  }
}
