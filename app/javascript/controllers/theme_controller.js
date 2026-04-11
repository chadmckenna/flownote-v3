import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.#updateLabel()
  }

  toggle() {
    const current = document.documentElement.getAttribute("data-theme")
    const next = current === "dark" ? "light" : "dark"

    document.documentElement.setAttribute("data-theme", next)
    document.documentElement.style.colorScheme = next
    localStorage.setItem("theme", next)
    this.#updateLabel()
  }

  #updateLabel() {
    const current = document.documentElement.getAttribute("data-theme")
    this.element.textContent = current === "dark" ? "☀️" : "🌙"
  }
}
