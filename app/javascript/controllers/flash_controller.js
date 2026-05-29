import { Controller } from "@hotwired/stimulus"

// Auto-dismisses an alert after a delay, then removes it from the DOM.
// Attached only to success flashes — errors render without it and stay put.
// Because turbo_stream.update replaces the flash slot, connect() fires for
// every new (page-load or async) success, so each one fades on its own.
export default class extends Controller {
  static values = { delay: { type: Number, default: 5000 } }

  connect() {
    this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
    this.element.classList.add("alert--leaving")
  }
}
