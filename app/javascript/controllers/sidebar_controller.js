import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.#updateLabel()
  }

  toggle() {
    const shell = this.#shell
    if (!shell) return

    const collapsed = shell.getAttribute("data-sidebar-collapsed") === "true"
    if (collapsed) {
      shell.removeAttribute("data-sidebar-collapsed")
    } else {
      shell.setAttribute("data-sidebar-collapsed", "true")
    }
    this.#updateLabel()
  }

  get #shell() {
    return this.element.closest(".folder-shell") || document.querySelector("main.folder-shell")
  }

  #updateLabel() {
    const collapsed = this.#shell?.getAttribute("data-sidebar-collapsed") === "true"
    this.element.textContent = collapsed ? "»" : "«"
    this.element.setAttribute("aria-expanded", collapsed ? "false" : "true")
  }
}
