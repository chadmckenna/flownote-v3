import { Controller } from "@hotwired/stimulus"

// Share modal holding a note's public link, keeping the note action bar compact.
// Mounted on the <dialog>, which sits outside the note form; the trigger button
// lives in the action bar inside it, so opening works the same way search does —
// off a document-level click on [data-share-open].
export default class extends Controller {
  static targets = [ "url" ]

  connect() {
    this.onClick = this.onClick.bind(this)
    document.addEventListener("click", this.onClick)
  }

  disconnect() {
    document.removeEventListener("click", this.onClick)
  }

  onClick(event) {
    if (event.target.closest("[data-share-open]")) {
      event.preventDefault()
      this.open()
    }
  }

  open() {
    if (this.element.open) return

    this.element.showModal()
    this.urlTarget.focus()
    this.urlTarget.select()
  }

  close() {
    this.element.close()
  }

  // Native <dialog> centers its content; clicks that land on the element itself
  // (rather than a child) are backdrop clicks.
  backdropClose(event) {
    if (event.target === this.element) this.close()
  }
}
