import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit(event) {
    event.preventDefault()

    const checkbox = event.currentTarget
    const form = checkbox.form
    if (!form || checkbox.disabled) return

    const scrollY = window.scrollY
    checkbox.disabled = true

    fetch(form.action, {
      method: form.method.toUpperCase(),
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: new FormData(form)
    }).then((response) => {
      if (!response.ok) throw new Error("Failed to toggle shopping item")

      return response.text()
    }).then((html) => {
      if (html.trim().length > 0) Turbo.renderStreamMessage(html)
      requestAnimationFrame(() => window.scrollTo({ top: scrollY, left: 0 }))
    }).catch(() => {
      checkbox.checked = !checkbox.checked
      checkbox.disabled = false
      window.alert("購入状態を更新できませんでした。")
    })
  }
}
