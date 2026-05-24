import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]

  toggle() {
    const visible = this.inputTarget.type === "text"
    this.inputTarget.type = visible ? "password" : "text"
    this.buttonTarget.textContent = visible ? "表示" : "非表示"
    this.buttonTarget.setAttribute("aria-pressed", String(!visible))
  }
}
