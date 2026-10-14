import { Controller } from "@hotwired/stimulus"
import { EditorState } from "@codemirror/state"
import {
  EditorView, keymap, lineNumbers, highlightActiveLine, highlightActiveLineGutter,
  highlightSpecialChars, drawSelection, dropCursor
} from "@codemirror/view"
import {
  HighlightStyle, syntaxHighlighting, indentOnInput, bracketMatching
} from "@codemirror/language"
import { tags } from "@lezer/highlight"
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands"
import { searchKeymap, highlightSelectionMatches } from "@codemirror/search"
import { markdown } from "@codemirror/lang-markdown"
import { autocompletion, closeCompletion } from "@codemirror/autocomplete"
import { vim, Vim, getCM } from "@replit/codemirror-vim"

const formFromVim = (cm) => cm.cm6?.dom.closest("form")

// :q and :view/:v click the form's Close / View links, so they behave exactly
// like those buttons — including Turbo's unsaved-changes prompt on navigation.
const clickNavFromVim = (cm, nav) => {
  formFromVim(cm)?.querySelector(`[data-note-nav="${nav}"]`)?.click()
}

Vim.defineEx("write", "w", (cm) => clickNavFromVim(cm, "save"))
Vim.defineEx("wq", "wq", (cm) => clickNavFromVim(cm, "save"))
Vim.defineEx("x", "x", (cm) => clickNavFromVim(cm, "save"))
Vim.defineEx("quit", "q", (cm) => clickNavFromVim(cm, "close"))
Vim.defineEx("view", "v", (cm) => clickNavFromVim(cm, "view"))

// Markdown in Rosé Pine's roles, through the same --color-syntax-* tokens as
// rendered code blocks, so the editor re-themes with the page. CodeMirror's
// default style hard-codes its colours for a light background.
const rosePine = HighlightStyle.define([
  { tag: tags.heading, color: "var(--color-syntax-function)", fontWeight: "bold" },
  { tag: tags.strong, fontWeight: "bold" },
  { tag: tags.emphasis, fontStyle: "italic" },
  { tag: tags.strikethrough, textDecoration: "line-through" },
  { tag: [tags.link, tags.url], color: "var(--color-link)" },
  { tag: tags.monospace, color: "var(--color-syntax-string)" },
  { tag: tags.quote, color: "var(--color-ink-muted)", fontStyle: "italic" },
  // The markup itself: #, -, >, ```, ** and friends.
  { tag: [tags.processingInstruction, tags.contentSeparator, tags.labelName], color: "var(--color-ink-muted)" },
  { tag: tags.keyword, color: "var(--color-syntax-keyword)" },
  { tag: [tags.string, tags.number], color: "var(--color-syntax-string)" },
  { tag: [tags.typeName, tags.tagName], color: "var(--color-syntax-type)" },
  { tag: [tags.attributeName, tags.propertyName], color: "var(--color-syntax-attribute)" },
  { tag: tags.comment, color: "var(--color-syntax-comment)", fontStyle: "italic" },
])

export default class extends Controller {
  static targets = ["textarea"]
  static values = { completions: Array }

  #dirty = false

  connect() {
    const ta = this.textareaTarget

    this.view = new EditorView({
      state: EditorState.create({
        doc: ta.value,
        extensions: [
          vim(),
          lineNumbers(),
          highlightActiveLineGutter(),
          highlightSpecialChars(),
          history(),
          drawSelection(),
          dropCursor(),
          EditorState.allowMultipleSelections.of(true),
          indentOnInput(),
          syntaxHighlighting(rosePine),
          bracketMatching(),
          highlightActiveLine(),
          highlightSelectionMatches(),
          keymap.of([
            ...defaultKeymap,
            ...searchKeymap,
            ...historyKeymap,
          ]),
          markdown(),
          // override: replaces every other source, so the markdown language's own
          // completions (it pulls in lang-html) can't pop up unasked. icons: false
          // drops the type-icon column, which would otherwise indent every row for
          // an icon these completions never set.
          autocompletion({ override: [ this.#noteLinkCompletions ], icons: false }),
          EditorView.lineWrapping,
          EditorView.updateListener.of((u) => {
            if (u.docChanged) this.#markDirty(true)
          }),
        ],
      }),
    })

    ta.style.display = "none"
    ta.insertAdjacentElement("afterend", this.view.dom)

    this.submitHandler = () => {
      ta.value = this.view.state.doc.toString()
      this.#markDirty(false)
    }
    ta.form?.addEventListener("submit", this.submitHandler)

    // Hard navigations (reload, tab close, typed URL): browser shows its own prompt.
    this.beforeUnloadHandler = (event) => {
      if (this.#dirty) event.preventDefault()
    }
    window.addEventListener("beforeunload", this.beforeUnloadHandler)

    // Turbo Drive visits (e.g. breadcrumb links that break out to _top).
    this.beforeVisitHandler = (event) => {
      if (this.#dirty && !this.#confirmDiscard()) event.preventDefault()
    }
    document.addEventListener("turbo:before-visit", this.beforeVisitHandler)

    // Preserve the CodeMirror-managed DOM (and any unsaved text) when Turbo morphs
    // this note's page in place — e.g. an incoming live-refresh broadcast. Navigating
    // to a different note instead replaces this element wholesale (its id changes), so
    // that path still re-initializes cleanly via disconnect/connect.
    this.preserveOnMorph = (event) => event.preventDefault()
    this.element.addEventListener("turbo:before-morph-element", this.preserveOnMorph)

    // Escape has to be handled through vim rather than the completion keymap:
    // vim() registers a raw keydown handler on the view, which runs ahead of
    // CodeMirror's keymap system entirely, so a binding for Escape would look
    // right and never fire. Leaving insert mode by any means dismisses the list.
    this.cm = getCM(this.view)
    this.closeOnModeChange = ({ mode }) => {
      if (mode !== "insert") closeCompletion(this.view)
    }
    this.cm?.on("vim-mode-change", this.closeOnModeChange)

    this.view.focus()
  }

  // Ctrl+Shift+I or L, the keys that open the editor from view mode, jump into
  // it when it's already open — from the sidebar, the note bar, wherever focus
  // wandered. L pairs with Ctrl+Shift+H for the sidebar: left and right. Bound on window in the capture phase so it's handled before vim
  // sees the chord (vim, fed a Ctrl+Shift chord, swallows the keys after it).
  focus(event) {
    event.preventDefault()
    this.view.focus()
  }

  disconnect() {
    this.textareaTarget.form?.removeEventListener("submit", this.submitHandler)
    window.removeEventListener("beforeunload", this.beforeUnloadHandler)
    document.removeEventListener("turbo:before-visit", this.beforeVisitHandler)
    this.element.removeEventListener("turbo:before-morph-element", this.preserveOnMorph)
    this.cm?.off("vim-mode-change", this.closeOnModeChange)
    this.view?.destroy()
    this.textareaTarget.style.display = ""
  }

  #confirmDiscard() {
    return confirm("You have unsaved changes. Leave without saving?")
  }

  // Published on the element so a jump through the browser's history can see it:
  // those are restoration visits, which never fire turbo:before-visit, so the
  // guard above can't catch them.
  #markDirty(dirty) {
    this.#dirty = dirty
    this.element.toggleAttribute("data-unsaved", dirty)
  }

  // Offers the user's notes after "[[". `from` skips the brackets so what you
  // type filters against the title itself, and accepting writes the closing
  // "]]" — nothing auto-closes brackets in this editor.
  #noteLinkCompletions = (context) => {
    const opener = context.matchBefore(/\[\[[^\[\]\n]*/)
    if (!opener) return null

    return {
      from: opener.from + 2,
      validFor: /^[^\[\]\n]*$/,
      options: this.completionsValue.map(({ label, detail, apply }) => ({
        label,
        detail,
        apply: this.#insertLink(apply),
      })),
    }
  }

  #insertLink(target) {
    return (view, _completion, from, to) => {
      const closed = view.state.sliceDoc(to, to + 2) === "]]"
      const insert = `${target}]]`

      view.dispatch({
        changes: { from, to: closed ? to + 2 : to, insert },
        selection: { anchor: from + insert.length },
        userEvent: "input.complete",
      })
    }
  }
}
