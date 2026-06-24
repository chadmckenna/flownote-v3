import { Controller } from "@hotwired/stimulus"

// Collapses the sidebar via data-sidebar-collapsed on .folder-shell. The state
// persists across navigations (localStorage); the attribute is client-only, so we
// re-inject it into the incoming body before every render to stay flicker-free.
// The toggle button is data-turbo-permanent, so this controller stays connected
// across visits. Clicking a breadcrumb folder link (data-sidebar-open) forces the
// sidebar open, so navigating to a folder from a collapsed state never lands on an
// empty pane.
const STORAGE_KEY = "sidebar-collapsed"

export default class extends Controller {
  connect() {
    this.#render(this.#stored)

    this.beforeRender = (event) => {
      const shell = event.detail.newBody?.querySelector(".folder-shell")
      if (shell && this.#stored) shell.setAttribute("data-sidebar-collapsed", "true")
    }
    this.forceOpen = (event) => {
      if (event.target.closest("[data-sidebar-open]")) this.#store(false)
    }
    document.addEventListener("turbo:before-render", this.beforeRender)
    document.addEventListener("click", this.forceOpen)
  }

  disconnect() {
    document.removeEventListener("turbo:before-render", this.beforeRender)
    document.removeEventListener("click", this.forceOpen)
  }

  toggle() {
    this.#store(!this.#stored)
  }

  #store(collapsed) {
    localStorage.setItem(STORAGE_KEY, collapsed ? "true" : "false")
    this.#render(collapsed)
  }

  #render(collapsed) {
    const shell = this.#shell
    if (!shell) return
    if (collapsed) {
      shell.setAttribute("data-sidebar-collapsed", "true")
    } else {
      shell.removeAttribute("data-sidebar-collapsed")
    }
    this.#updateLabel(collapsed)
  }

  get #stored() {
    return localStorage.getItem(STORAGE_KEY) === "true"
  }

  get #shell() {
    return this.element.closest(".folder-shell") || document.querySelector("main.folder-shell")
  }

  #updateLabel(collapsed) {
    this.element.textContent = collapsed ? "»" : "«"
    this.element.setAttribute("aria-expanded", collapsed ? "false" : "true")
  }
}
