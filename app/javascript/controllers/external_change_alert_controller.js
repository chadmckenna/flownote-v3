import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.streamHandler = this.handleStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.streamHandler)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.streamHandler)
  }

  handleStreamRender(event) {
    if (event.target?.getAttribute("action") === "refresh") {
      event.preventDefault()
      this.element.hidden = false
    }
  }
}
