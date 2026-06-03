import { Controller } from "@hotwired/stimulus"
import { EditorState } from "@codemirror/state"
import {
  EditorView, keymap, lineNumbers, highlightActiveLine, highlightActiveLineGutter,
  highlightSpecialChars, drawSelection, dropCursor
} from "@codemirror/view"
import {
  defaultHighlightStyle, syntaxHighlighting, indentOnInput, bracketMatching
} from "@codemirror/language"
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands"
import { searchKeymap, highlightSelectionMatches } from "@codemirror/search"
import { markdown } from "@codemirror/lang-markdown"
import { vim, Vim } from "@replit/codemirror-vim"

const submitFromVim = (cm) => {
  const form = cm.cm6?.dom.closest("form")
  form?.requestSubmit()
}
Vim.defineEx("write", "w", submitFromVim)
Vim.defineEx("wq", "wq", submitFromVim)
Vim.defineEx("x", "x", submitFromVim)

export default class extends Controller {
  static targets = ["textarea"]

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
          syntaxHighlighting(defaultHighlightStyle, { fallbackToCodeMirror: true }),
          bracketMatching(),
          highlightActiveLine(),
          highlightSelectionMatches(),
          keymap.of([
            ...defaultKeymap,
            ...searchKeymap,
            ...historyKeymap,
          ]),
          markdown(),
          EditorView.lineWrapping,
          EditorView.updateListener.of((u) => {
            if (u.docChanged) this.#dirty = true
          }),
        ],
      }),
    })

    ta.style.display = "none"
    ta.insertAdjacentElement("afterend", this.view.dom)

    this.submitHandler = () => {
      ta.value = this.view.state.doc.toString()
      this.#dirty = false
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

    this.view.focus()
  }

  disconnect() {
    this.textareaTarget.form?.removeEventListener("submit", this.submitHandler)
    window.removeEventListener("beforeunload", this.beforeUnloadHandler)
    document.removeEventListener("turbo:before-visit", this.beforeVisitHandler)
    this.element.removeEventListener("turbo:before-morph-element", this.preserveOnMorph)
    this.view?.destroy()
    this.textareaTarget.style.display = ""
  }

  #confirmDiscard() {
    return confirm("You have unsaved changes. Leave without saving?")
  }
}
