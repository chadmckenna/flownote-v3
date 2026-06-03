import { Controller } from "@hotwired/stimulus"

// Toggles sidebar collapse via data-sidebar-collapsed on the .folder-shell <main>.
// That attribute is client-only, so on morph navigations (where the server never
// renders it) we inject it into the incoming body before render to keep the state
// stable and flicker-free.
const STORAGE_KEY = "sidebar-collapsed"

export default class extends Controller {
  connect() {
    this.#apply(this.#stored)
    this.beforeRender = (event) => {
      const shell = event.detail.newBody?.querySelector(".folder-shell")
      if (shell && this.#stored) shell.setAttribute("data-sidebar-collapsed", "true")
    }
    document.addEventListener("turbo:before-render", this.beforeRender)
  }

  disconnect() {
    document.removeEventListener("turbo:before-render", this.beforeRender)
  }

  toggle() {
    this.#apply(!(this.#shell?.getAttribute("data-sidebar-collapsed") === "true"))
  }

  #apply(collapsed) {
    const shell = this.#shell
    if (!shell) return
    if (collapsed) {
      shell.setAttribute("data-sidebar-collapsed", "true")
    } else {
      shell.removeAttribute("data-sidebar-collapsed")
    }
    localStorage.setItem(STORAGE_KEY, collapsed ? "true" : "false")
    this.#updateLabel()
  }

  get #stored() {
    return localStorage.getItem(STORAGE_KEY) === "true"
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
