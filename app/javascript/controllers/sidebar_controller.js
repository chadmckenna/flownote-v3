import { Controller } from "@hotwired/stimulus"

// Toggles sidebar collapse via data-sidebar-collapsed on the .folder-shell <main>.
//
// Collapse is a manual, ephemeral action: the only way to collapse is the toggle
// button, and every navigation defaults back to open. The attribute is client-only
// (the server never renders it), so same-page morph refreshes — live updates and
// save redirects — would otherwise drop it; we re-inject it before a morph render
// to keep editing flicker-free. A "replace" render is a real navigation and is left
// to default open.
export default class extends Controller {
  connect() {
    this.#updateLabel()
    this.beforeRender = (event) => {
      if (event.detail.renderMethod !== "morph") return
      const shell = event.detail.newBody?.querySelector(".folder-shell")
      if (shell && this.#collapsed) shell.setAttribute("data-sidebar-collapsed", "true")
    }
    document.addEventListener("turbo:before-render", this.beforeRender)
  }

  disconnect() {
    document.removeEventListener("turbo:before-render", this.beforeRender)
  }

  toggle() {
    const shell = this.#shell
    if (!shell) return
    if (this.#collapsed) {
      shell.removeAttribute("data-sidebar-collapsed")
    } else {
      shell.setAttribute("data-sidebar-collapsed", "true")
    }
    this.#updateLabel()
  }

  get #collapsed() {
    return this.#shell?.getAttribute("data-sidebar-collapsed") === "true"
  }

  get #shell() {
    return this.element.closest(".folder-shell") || document.querySelector("main.folder-shell")
  }

  #updateLabel() {
    const collapsed = this.#collapsed
    this.element.textContent = collapsed ? "»" : "«"
    this.element.setAttribute("aria-expanded", collapsed ? "false" : "true")
  }
}
