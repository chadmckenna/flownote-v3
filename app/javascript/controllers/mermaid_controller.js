import { Controller } from "@hotwired/stimulus"

// Renders fenced ```mermaid code blocks as diagrams. Mermaid is a large library
// and rarely used, so it's lazily imported from the CDN only when a note
// actually contains a diagram — normal notes pay nothing. Re-renders on Turbo
// morphs (navigating between notes, or a live-refresh), mirroring
// syntax_highlight_controller, which is set up to leave mermaid blocks alone.
let mermaidModule
let uid = 0

export default class extends Controller {
  connect() {
    this.#render()
    this.morphHandler = () => this.#render()
    this.element.addEventListener("turbo:morph-element", this.morphHandler)
  }

  disconnect() {
    this.element.removeEventListener("turbo:morph-element", this.morphHandler)
  }

  async #render() {
    const blocks = this.element.querySelectorAll("pre code.language-mermaid")
    if (blocks.length === 0) return

    const mermaid = await this.#load()

    blocks.forEach(async (block) => {
      const pre = block.closest("pre")
      // A morph restores the original <pre><code> (the server never sends the
      // SVG), stripping this flag, so re-rendering picks up where it left off.
      if (pre.dataset.mermaidRendered === "true") return
      pre.dataset.mermaidRendered = "true"

      const source = block.textContent
      try {
        const { svg } = await mermaid.render(`mermaid-${uid++}`, source)
        pre.innerHTML = svg
        pre.classList.add("mermaid-diagram")
      } catch (error) {
        // Leave the raw code visible and allow a later morph to retry.
        delete pre.dataset.mermaidRendered
        console.error("Mermaid render failed:", error)
      }
    })
  }

  #load() {
    if (!mermaidModule) {
      mermaidModule = import("https://cdn.jsdelivr.net/npm/mermaid@11/+esm").then((m) => {
        m.default.initialize({ startOnLoad: false, theme: this.#theme() })
        return m.default
      })
    }
    return mermaidModule
  }

  #theme() {
    const explicit = document.documentElement.dataset.theme
    const dark = explicit === "dark" ||
      (!explicit && window.matchMedia?.("(prefers-color-scheme: dark)").matches)
    return dark ? "dark" : "default"
  }
}
