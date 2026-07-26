import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["list", "item", "handle", "status"]
  static values = { url: String }

  connect() {
    this.confirmedOrder = this.currentOrder()
    this.saving = false
    this.keyboardItemId = null
    this.keyboardStartOrder = null

    if (this.itemTargets.length >= 2) {
      this.sortable = Sortable.create(this.listTarget, {
        animation: 180,
        handle: ".person-tag-sort-handle",
        draggable: "[data-person-tag-sort-target='item']",
        ghostClass: "person-tag-row-ghost",
        chosenClass: "person-tag-row-chosen",
        dragClass: "person-tag-row-drag",
        onEnd: (event) => this.saveOrder(event.item.dataset.personTagId)
      })
    }
  }

  disconnect() {
    this.sortable?.destroy()
  }

  handleKeydown(event) {
    if (this.saving || this.itemTargets.length < 2) return

    const item = event.currentTarget.closest("[data-person-tag-sort-target='item']")
    if (!item) return

    if (event.key === " " || event.key === "Enter") {
      event.preventDefault()
      this.keyboardItemId ? this.dropKeyboardItem() : this.pickUpKeyboardItem(item)
      return
    }

    if (event.key === "Escape" && this.keyboardItemId) {
      event.preventDefault()
      this.cancelKeyboardMove()
      return
    }

    if (!this.keyboardItemId || item.dataset.personTagId !== this.keyboardItemId) return

    const destinations = {
      ArrowUp: this.itemTargets.indexOf(item) - 1,
      ArrowDown: this.itemTargets.indexOf(item) + 1,
      Home: 0,
      End: this.itemTargets.length - 1
    }
    if (!(event.key in destinations)) return

    event.preventDefault()
    this.moveKeyboardItem(item, destinations[event.key])
  }

  currentOrder() {
    return this.itemTargets.map((item) => item.dataset.personTagId)
  }

  pickUpKeyboardItem(item) {
    this.keyboardItemId = item.dataset.personTagId
    this.keyboardStartOrder = this.currentOrder()
    this.updateSortableDisabled()
    this.updatePickedUpHandle()
    this.announcePosition(item, "持ち上げました")
  }

  dropKeyboardItem() {
    const itemId = this.keyboardItemId
    const item = this.itemForId(itemId)
    this.keyboardItemId = null
    this.keyboardStartOrder = null
    this.updateSortableDisabled()
    this.updatePickedUpHandle()
    this.setStatus(`${item.dataset.personTagName}を配置しました。並び順を保存します。`)
    this.saveOrder(itemId)
  }

  cancelKeyboardMove() {
    const itemId = this.keyboardItemId
    const item = this.itemForId(itemId)
    this.restoreOrder(this.keyboardStartOrder)
    this.keyboardItemId = null
    this.keyboardStartOrder = null
    this.updateSortableDisabled()
    this.updatePickedUpHandle()
    this.setStatus(`${item.dataset.personTagName}の移動をキャンセルしました。`)
    this.focusHandle(itemId)
  }

  moveKeyboardItem(item, destinationIndex) {
    const currentIndex = this.itemTargets.indexOf(item)
    const boundedIndex = Math.max(0, Math.min(destinationIndex, this.itemTargets.length - 1))
    if (boundedIndex === currentIndex) {
      this.announcePosition(item, "これ以上移動できません")
      return
    }

    const items = this.itemTargets
    if (boundedIndex < currentIndex) {
      this.listTarget.insertBefore(item, items[boundedIndex])
    } else {
      this.listTarget.insertBefore(item, items[boundedIndex].nextSibling)
    }
    this.announcePosition(item, "移動しました")
    this.focusHandle(item.dataset.personTagId)
  }

  announcePosition(item, action) {
    const position = this.itemTargets.indexOf(item) + 1
    this.setStatus(`${item.dataset.personTagName}を${action}。現在${position}番目、全${this.itemTargets.length}件です。`)
  }

  async saveOrder(focusItemId) {
    if (this.saving || !this.hasUrlValue) return

    const requestedOrder = this.currentOrder()
    if (this.sameOrder(requestedOrder, this.confirmedOrder)) {
      this.setStatus("並び順は変更されていません。")
      this.focusHandle(focusItemId)
      return
    }

    this.setSaving(true)
    this.setStatus("並び順を保存しています…")

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: JSON.stringify({ ids: requestedOrder })
      })
      const contentType = response.headers.get("Content-Type") || ""
      if (!response.ok || response.redirected || !contentType.includes("application/json")) {
        throw new Error("Unexpected reorder response")
      }

      const body = await response.json()
      if (body.ok !== true) throw new Error("Rejected reorder response")

      this.confirmedOrder = requestedOrder
      this.setStatus("並び順を保存しました。")
    } catch (_error) {
      this.restoreOrder(this.confirmedOrder)
      this.setStatus("並び順を保存できなかったため、保存済みの順序へ戻しました。")
      window.alert("並び順を保存できませんでした。")
    } finally {
      this.setSaving(false)
      this.focusHandle(focusItemId)
    }
  }

  setSaving(saving) {
    this.saving = saving
    this.listTarget.setAttribute("aria-busy", saving.toString())
    this.updateSortableDisabled()
    this.handleTargets.forEach((handle) => {
      handle.disabled = saving || this.itemTargets.length < 2
    })
  }

  updateSortableDisabled() {
    this.sortable?.option("disabled", this.saving || Boolean(this.keyboardItemId))
  }

  setStatus(message) {
    this.statusTarget.textContent = message
  }

  restoreOrder(order) {
    const itemsById = new Map(this.itemTargets.map((item) => [item.dataset.personTagId, item]))
    order.forEach((id) => {
      const item = itemsById.get(id)
      if (item) this.listTarget.appendChild(item)
    })
  }

  itemForId(id) {
    return this.itemTargets.find((item) => item.dataset.personTagId === id)
  }

  focusHandle(itemId) {
    if (!itemId) return

    this.itemForId(itemId)?.querySelector("[data-person-tag-sort-target='handle']")?.focus()
  }

  updatePickedUpHandle() {
    this.handleTargets.forEach((handle) => {
      const pickedUp = handle.closest("[data-person-tag-sort-target='item']")?.dataset.personTagId === this.keyboardItemId
      handle.setAttribute("aria-pressed", pickedUp.toString())
    })
  }

  sameOrder(left, right) {
    return left.length === right.length && left.every((id, index) => id === right[index])
  }
}
