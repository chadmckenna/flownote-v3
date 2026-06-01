import { Controller } from "@hotwired/stimulus"
import hljs from "highlight.js"

// Highlights fenced code blocks in rendered markdown. Runs on connect and again
// whenever Turbo morphs the article in place (navigating between notes, or a
// live-refresh), re-highlighting idempotently.
export default class extends Controller {
  connect() {
    this.#highlight()
    this.morphHandler = () => this.#highlight()
    this.element.addEventListener("turbo:morph-element", this.morphHandler)
  }

  disconnect() {
    this.element.removeEventListener("turbo:morph-element", this.morphHandler)
  }

  #highlight() {
    this.element.querySelectorAll("pre code").forEach((block) => {
      delete block.dataset.highlighted
      hljs.highlightElement(block)
    })
  }
}
