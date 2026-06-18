import { Controller } from "@hotwired/stimulus"

// Sets data-theme on <html>; the sun/moon icons in the toggle button are shown
// or hidden via CSS based on that attribute (see navigation.css).
export default class extends Controller {
  connect() {
    const saved = localStorage.getItem("theme")
    this.#apply(saved || (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"))
  }

  toggle() {
    const next = document.documentElement.getAttribute("data-theme") === "dark" ? "light" : "dark"
    this.#apply(next)
    localStorage.setItem("theme", next)
  }

  #apply(theme) {
    document.documentElement.setAttribute("data-theme", theme)
    document.documentElement.style.colorScheme = theme
  }
}
