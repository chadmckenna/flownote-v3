import { Controller } from "@hotwired/stimulus"
import hljs from "highlight.js"

// Highlights fenced code blocks in rendered markdown. Attached to the viewing
// article; re-runs on connect, so it re-highlights when the editor_main Turbo
// frame is swapped between notes.
export default class extends Controller {
  connect() {
    this.element.querySelectorAll("pre code").forEach((block) => hljs.highlightElement(block))
  }
}
