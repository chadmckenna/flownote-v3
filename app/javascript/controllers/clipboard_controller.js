import { Controller } from "@hotwired/stimulus"

// Copies the source target's value to the clipboard and briefly swaps the
// button's label. The Clipboard API is unavailable on insecure origins, so
// failures fall back to selecting the text for a manual copy.
export default class extends Controller {
  #resetTimer

  static targets = [ "source", "button" ]
  static values = {
    label: { type: String, default: "Copy" },
    copiedLabel: { type: String, default: "Copied!" },
    resetDelay: { type: Number, default: 2000 }
  }

  // Turbo can cache a snapshot mid-flash, restoring a button that still reads
  // "Copied!". The label always comes from the value, never from the DOM.
  connect() {
    this.#label = this.labelValue
  }

  disconnect() {
    clearTimeout(this.#resetTimer)
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
    } catch {
      this.sourceTarget.select()
      return
    }

    this.#flash()
  }

  #flash() {
    clearTimeout(this.#resetTimer)
    this.#label = this.copiedLabelValue
    this.#resetTimer = setTimeout(() => { this.#label = this.labelValue }, this.resetDelayValue)
  }

  set #label(text) {
    this.buttonTarget.textContent = text
  }
}
