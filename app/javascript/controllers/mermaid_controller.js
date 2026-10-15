import { Controller } from "@hotwired/stimulus"

// Renders fenced ```mermaid code blocks as diagrams, in the app's own palette
// for whichever theme is showing, and redraws them when the theme changes.
// Mermaid is a large library and rarely used, so it's lazily imported from the
// CDN only when a note actually contains a diagram — normal notes pay nothing.
// Re-renders on Turbo morphs (navigating between notes, or a live-refresh),
// mirroring syntax_highlight_controller, which is set up to leave mermaid
// blocks alone.
let mermaidModule
let uid = 0

export default class extends Controller {
  connect() {
    this.#render()
    this.morphHandler = () => this.#render()
    this.element.addEventListener("turbo:morph-element", this.morphHandler)
    // The theme toggle flips data-theme on <html>: redraw in the new colours.
    this.themeObserver = new MutationObserver(() => this.#render({ redraw: true }))
    this.themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: [ "data-theme" ] })
  }

  disconnect() {
    this.element.removeEventListener("turbo:morph-element", this.morphHandler)
    this.themeObserver.disconnect()
  }

  async #render({ redraw = false } = {}) {
    const blocks = [ ...this.element.querySelectorAll("pre code.language-mermaid") ]
      .map((code) => ({ pre: code.closest("pre"), source: code.textContent }))
    if (redraw) {
      this.element.querySelectorAll("pre.mermaid-diagram").forEach((pre) => {
        blocks.push({ pre, source: pre.dataset.mermaidSource })
      })
    }
    if (blocks.length === 0) return

    const mermaid = await this.#load()
    mermaid.initialize({ startOnLoad: false, theme: "base", themeVariables: palette() })

    for (const { pre, source } of blocks) {
      // A morph restores the original <pre><code> (the server never sends the
      // SVG), stripping this flag, so re-rendering picks up where it left off.
      if (pre.dataset.mermaidRendering === "true") continue
      pre.dataset.mermaidRendering = "true"
      try {
        const { svg } = await mermaid.render(`mermaid-${uid++}`, source)
        pre.innerHTML = svg
        pre.dataset.mermaidSource = source
        pre.classList.add("mermaid-diagram")
      } catch (error) {
        // Leave the raw code visible and allow a later morph to retry.
        console.error("Mermaid render failed:", error)
      } finally {
        delete pre.dataset.mermaidRendering
      }
    }
  }

  // Mermaid's own ESM build, not jsDelivr's +esm rewrite: that rewrite gives
  // each lazily loaded diagram type (pie, gantt, ...) its own copy of Mermaid's
  // config module, so those diagrams ignore the theme set here.
  #load() {
    mermaidModule ||= import("https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs").then((m) => m.default)
    return mermaidModule
  }
}

// Mermaid's theme variables, from the --color-* tokens in _global.css as the
// current theme sets them. Mermaid derives shades from these with a parser
// that reads hex and rgb but not oklch or color-mix, so the browser resolves
// each token and it's read back as hex.
function palette() {
  const probe = document.createElement("span")
  document.body.append(probe)
  const canvas = document.createElement("canvas")
  canvas.width = canvas.height = 1
  const context = canvas.getContext("2d", { willReadFrequently: true })

  const hex = (token) => {
    probe.style.color = `var(--color-${token})`
    context.clearRect(0, 0, 1, 1)
    context.fillStyle = getComputedStyle(probe).color
    context.fillRect(0, 0, 1, 1)
    const [ r, g, b ] = context.getImageData(0, 0, 1, 1).data
    return "#" + [ r, g, b ].map((n) => n.toString(16).padStart(2, "0")).join("")
  }

  const canvasColor = hex("canvas"), card = hex("card"), shade = hex("shade"), highlight = hex("highlight")
  const ink = hex("ink"), muted = hex("ink-muted"), border = hex("border"), strong = hex("border-strong")
  const accent = hex("accent")
  // Rosé Pine's six accent hues (pine, gold, iris, rose, foam, love), through
  // the tokens that carry them in both themes, ordered so neighbouring slices
  // never share a hue.
  const series = [ "syntax-keyword", "syntax-string", "syntax-attribute", "syntax-function",
    "syntax-type", "negative" ].map(hex)
  const explicit = document.documentElement.dataset.theme
  const dark = explicit === "dark" || (!explicit && window.matchMedia?.("(prefers-color-scheme: dark)").matches)
  const fontFamily = getComputedStyle(document.body).fontFamily
  probe.remove()

  return {
    darkMode: dark,
    fontFamily,
    background: canvasColor,
    textColor: ink,
    titleColor: ink,
    lineColor: muted,

    primaryColor: shade,
    primaryTextColor: ink,
    primaryBorderColor: accent,
    secondaryColor: highlight,
    secondaryTextColor: ink,
    secondaryBorderColor: strong,
    tertiaryColor: card,
    tertiaryTextColor: ink,
    tertiaryBorderColor: border,

    mainBkg: shade,
    nodeBorder: accent,
    clusterBkg: card,
    clusterBorder: strong,
    edgeLabelBackground: canvasColor,
    noteBkgColor: highlight,
    noteTextColor: ink,
    noteBorderColor: strong,

    actorBkg: shade,
    actorBorder: accent,
    actorTextColor: ink,
    actorLineColor: muted,
    signalColor: ink,
    signalTextColor: ink,
    labelBoxBkgColor: shade,
    labelBoxBorderColor: strong,
    labelTextColor: ink,
    loopTextColor: ink,
    activationBkgColor: highlight,
    activationBorderColor: strong,
    sequenceNumberColor: canvasColor,

    errorBkgColor: hex("negative"),
    errorTextColor: canvasColor,

    pieTitleTextColor: ink,
    pieSectionTextColor: canvasColor,
    pieLegendTextColor: ink,
    pieStrokeColor: canvasColor,
    pieOuterStrokeColor: strong,
    pieOpacity: "1",
    // Pie slices and mindmap/timeline sections, cycling through the hues.
    ...Object.fromEntries(Array.from({ length: 12 }, (_, i) => [
      [ `pie${i + 1}`, series[i % series.length] ],
      [ `cScale${i}`, series[i % series.length] ]
    ]).flat())
  }
}
