import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.update = this.update.bind(this)
    this.update()
    document.addEventListener("turbo:load", this.update)
    document.addEventListener("turbo:frame-load", this.update)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.update)
    document.removeEventListener("turbo:frame-load", this.update)
  }

  update() {
    const path = window.location.pathname
    this.element.querySelectorAll('li[aria-current="page"]').forEach((el) => el.removeAttribute("aria-current"))
    const link = this.element.querySelector(`a[href="${path}"]`)
    const li = link?.closest("li")
    if (li) li.setAttribute("aria-current", "page")
  }
}
