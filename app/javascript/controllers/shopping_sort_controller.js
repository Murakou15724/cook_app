import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["item"]
  static values = { url: String }

  connect() {
    this.previousOrder = this.currentOrder()
    this.sortable = Sortable.create(this.element, {
      animation: 180,
      handle: ".drag-handle",
      draggable: "[data-shopping-sort-target='item']",
      ghostClass: "shopping-row-ghost",
      chosenClass: "shopping-row-chosen",
      dragClass: "shopping-row-drag",
      onStart: () => {
        this.previousOrder = this.currentOrder()
      },
      onEnd: () => {
        this.saveOrder()
      }
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  currentOrder() {
    return this.itemTargets.map((item) => item.dataset.shoppingItemId)
  }

  saveOrder() {
    if (!this.hasUrlValue) return

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({ ids: this.currentOrder() })
    }).then((response) => {
      if (!response.ok) throw new Error("Failed to save order")
      this.previousOrder = this.currentOrder()
    }).catch(() => {
      this.restorePreviousOrder()
      window.alert("並び順を保存できませんでした。")
    })
  }

  restorePreviousOrder() {
    const itemsById = new Map(this.itemTargets.map((item) => [item.dataset.shoppingItemId, item]))
    this.previousOrder.forEach((id) => {
      const item = itemsById.get(id)
      if (item) this.element.appendChild(item)
    })
  }
}
