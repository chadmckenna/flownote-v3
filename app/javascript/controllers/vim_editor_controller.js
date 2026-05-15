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
            if (u.docChanged) ta.value = u.state.doc.toString()
          }),
        ],
      }),
    })

    ta.style.display = "none"
    ta.insertAdjacentElement("afterend", this.view.dom)

    this.submitHandler = () => { ta.value = this.view.state.doc.toString() }
    ta.form?.addEventListener("submit", this.submitHandler)
  }

  disconnect() {
    this.textareaTarget.form?.removeEventListener("submit", this.submitHandler)
    this.view?.destroy()
    this.textareaTarget.style.display = ""
  }
}
