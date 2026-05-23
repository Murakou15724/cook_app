import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "drawer", "form"]

  open() {
    this.backdropTarget.hidden = false
    this.drawerTarget.hidden = false
    this.formTarget.querySelector("input[type='date']")?.focus()
  }

  close() {
    this.backdropTarget.hidden = true
    this.drawerTarget.hidden = true
  }

  save() {
    if (!this.hasFormTarget) return

    fetch(this.formTarget.action, {
      method: "POST",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: new FormData(this.formTarget)
    }).then((response) => {
      return response.text().then((html) => {
        if (response.ok) this.close()
        if (html.trim().length > 0) Turbo.renderStreamMessage(html)
      })
    })
  }
}
