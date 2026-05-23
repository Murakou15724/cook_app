import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "drawer", "body", "template", "ingredientTemplate", "ingredientRow", "deleteField"]

  open(event) {
    const trigger = event.currentTarget
    const template = trigger.nextElementSibling
    if (!template) return

    this.bodyTarget.innerHTML = template.innerHTML
    this.backdropTarget.hidden = false
    this.drawerTarget.hidden = false
    this.bodyTarget.querySelector("input[type='text']")?.focus()
  }

  close() {
    this.backdropTarget.hidden = true
    this.drawerTarget.hidden = true
    this.bodyTarget.innerHTML = ""
  }

  save() {
    const form = this.bodyTarget.querySelector("form")
    if (!form) return

    fetch(form.action, {
      method: "PATCH",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: new FormData(form)
    }).then((response) => {
      return response.text().then((html) => {
        if (response.ok) this.close()
        if (html.trim().length > 0) Turbo.renderStreamMessage(html)
      })
    })
  }

  addIngredient(event) {
    const dishId = event.currentTarget.dataset.dishId
    const list = this.bodyTarget.querySelector(`.drawer-ingredient-list[data-dish-id="${dishId}"]`)
    if (!list) return

    const key = `new_${Date.now()}_${Math.floor(Math.random() * 1000)}`
    const wrapper = document.createElement("div")
    wrapper.innerHTML = this.ingredientTemplateTarget.innerHTML.trim()
    const row = wrapper.firstElementChild
    const input = row.querySelector("input[type='text']")
    input.name = `ingredients[${key}][name]`
    row.insertAdjacentHTML("afterbegin", `<input type="hidden" name="ingredients[${key}][dish_id]" value="${dishId}">`)
    list.appendChild(row)
    input.focus()
  }

  removeIngredient(event) {
    const row = event.currentTarget.closest(".drawer-ingredient-row")
    if (!row) return

    const deleteField = row.querySelector("input[name$='[delete]']")
    if (deleteField) {
      deleteField.value = "1"
      row.hidden = true
    } else {
      row.remove()
    }
  }
}
