import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "drawer", "nameInput", "context"]

  open(event) {
    this.updateUrl = event.params.updateUrl
    this.deleteUrl = event.params.deleteUrl
    this.nameInputTarget.value = event.params.name
    this.contextTarget.textContent = event.params.context
    this.backdropTarget.hidden = false
    this.drawerTarget.hidden = false
    this.nameInputTarget.focus()
  }

  close() {
    this.backdropTarget.hidden = true
    this.drawerTarget.hidden = true
    this.updateUrl = null
    this.deleteUrl = null
  }

  save() {
    if (!this.updateUrl) return

    this.submit(this.updateUrl, "PATCH", {
      shopping_item: { name: this.nameInputTarget.value }
    })
  }

  destroy() {
    if (!this.deleteUrl || !window.confirm("本当に削除しますか？")) return

    this.submit(this.deleteUrl, "DELETE")
  }

  submit(url, method, body = null) {
    return fetch(url, {
      method,
      headers: {
        "Content-Type": "application/json",
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: body ? JSON.stringify(body) : null
    }).then((response) => {
      return response.text().then((html) => {
        if (response.ok) this.close()
        if (html.trim().length > 0) Turbo.renderStreamMessage(html)
        return response.ok
      })
    })
  }
}
