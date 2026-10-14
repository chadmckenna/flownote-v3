import { Controller } from "@hotwired/stimulus"

// nvim-tree for the sidebar. Ctrl+Shift+H jumps into the listing from anywhere,
// editor included, as Ctrl+Shift+L jumps back to the editor — h and l, left and
// right (Ctrl+Shift+* is the app's global chord, see history_controller). Once
// it has focus:
//
//   ↓ / j, ↑ / k     next / previous row
//   → / l, Enter     open the folder or note
//   ← / h            up to the parent folder
//   a / A            new note / new folder here
//   r                rename the note or folder under the cursor, in place
//   d                delete the note or folder under the cursor
//   Esc              back to the editor (or the page, for scroll-keys)
//
// Renaming lives only here. Without a keyboard, tap the open note's row again
// to rename it; a folder is renamed with "Edit folder" once you're inside it.
//
// Rows are plain links, so this only moves real focus between them. These keys
// are handled on the sidebar, ahead of scroll-keys on the document, which skips
// anything already handled — so j/k move the listing, not the note behind it.
//
// Every action but opening a note ends in a visit that re-renders the sidebar:
// replacing it (another folder) or morphing it (this page again, after a create,
// rename, delete, or Esc out of the form). Either way focus drops to <body>, so
// it's carried across by hand, to wherever nvim-tree would leave the cursor.

// Lives in the module so it survives the visit. Honored only if the visit that
// landed is the one expected and nothing else has taken focus since: a confirm
// or an unsaved-changes prompt can call it off.
let pending = null

export default class extends Controller {
  static targets = ["parent", "newNote", "newFolder"]
  static values = { folder: String }

  connect() {
    this.onLoad = () => {
      if (pending?.to === location.pathname && document.activeElement === document.body) this.#land(pending)
      pending = null
    }
    document.addEventListener("turbo:load", this.onLoad)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.onLoad)
  }

  // Bound on window in the capture phase, so this runs before the editor sees
  // the chord: CodeMirror skips its handlers for an event that's already been
  // handled, and vim, fed a Ctrl+Shift+H, swallows the keys typed after it.
  focus(event) {
    event.preventDefault()
    if (!this.element.checkVisibility()) document.getElementById("sidebar-toggle")?.click()
    ;(this.element.querySelector("[aria-current] a") || this.#links[0] || this.element).focus()
  }

  renameOpenNote(event) {
    const link = event.target.closest("li[aria-current] a")
    if (!link || event.ctrlKey || event.altKey || event.metaKey || event.shiftKey) return
    event.preventDefault()
    this.#rename(link)
  }

  navigate(event) {
    // Shift is for "A" only: a shifted Enter or arrow keeps its browser meaning.
    if (event.ctrlKey || event.altKey || event.metaKey || (event.shiftKey && event.key.length > 1)) return
    // A row, or the sidebar itself when the folder is empty — not its forms.
    const link = event.target.closest(".file-listing a")
    if (!link && event.target !== this.element) return

    switch (event.key) {
      case "ArrowDown": case "j": this.#move(link, 1); break
      case "ArrowUp": case "k": this.#move(link, -1); break
      case "ArrowRight": case "l": case "Enter": if (link) this.#open(link); break
      case "ArrowLeft": case "h": if (this.hasParentTarget) this.#open(this.parentTarget); break
      case "a": this.#expect(location.pathname, link); this.newNoteTarget.click(); break
      case "A": this.#expect(location.pathname, link); this.newFolderTarget.click(); break
      case "r": this.#rename(link); break
      case "d": this.#delete(link); break
      case "Escape": this.#leave(); break
      default: return
    }
    event.preventDefault()
  }

  #move(link, step) {
    const links = this.#links
    links[links.indexOf(link) + step]?.focus()
  }

  // A note opens in the editor, which takes focus; a folder keeps it here. The
  // note that's already open just gets focus back (clicking its row renames it).
  #open(link) {
    if (link.closest("li[aria-current]")) return this.#leave()
    if (link.querySelector(".file-listing__name--folder")) this.#expect(link.pathname, link)
    link.click()
  }

  // Rows that can be renamed carry their form's URL, and each carries a hidden
  // delete form (_sidebar.html.erb) — all but "../".
  #rename(link) {
    if (!link?.dataset.editUrl) return
    this.#expect(location.pathname, link)
    link.closest("turbo-frame").src = link.dataset.editUrl
  }

  #delete(link) {
    const form = link?.closest("li").querySelector("form")
    if (!form) return
    // Delete the open note and its page goes with it: you land on the folder.
    this.#expect(link.closest("li[aria-current]") ? this.folderValue : location.pathname, link)
    form.requestSubmit()
  }

  #leave() {
    const editor = document.querySelector(".cm-content")
    editor ? editor.focus() : document.activeElement.blur()
  }

  #expect(to, link) {
    const rows = this.#rows
    pending = { to, from: location.pathname, row: link?.pathname, index: rows.indexOf(link), known: rows.map((row) => row.pathname) }
  }

  // Where nvim-tree leaves the cursor, first match wins: on the folder you just
  // came up out of; on a row that wasn't there before (the top of a folder you
  // went into, or the folder you just made); back on the row you acted on (Esc,
  // rename); or, if that row is gone (delete), on the one that took its place.
  #land({ from, row, index, known }) {
    const rows = this.#rows
    const target =
      rows.find((link) => link.pathname === from) ||
      rows.find((link) => !known.includes(link.pathname)) ||
      rows.find((link) => link.pathname === row) ||
      rows[Math.min(index, rows.length - 1)] ||
      this.#links[0] ||
      this.element
    target.focus()
  }

  // Every row but "../".
  get #rows() {
    return this.#links.filter((link) => !this.parentTargets.includes(link))
  }

  get #links() {
    return Array.from(this.element.querySelectorAll(".file-listing a"))
  }
}
