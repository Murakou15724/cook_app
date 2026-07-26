import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "dishes",
    "dish",
    "dishNumber",
    "removeDishButton",
    "dishTemplate",
    "addDishButton",
    "ingredients",
    "ingredient",
    "ingredientTemplate"
  ]
  static values = {
    allowEmptyDishes: { type: Boolean, default: false },
    confirmDishRemoval: { type: Boolean, default: false }
  }

  connect() {
    this.refreshDishControls()
  }

  addDish() {
    const dishIndex = this.nextDishIndex()
    const html = this.dishTemplateTarget.innerHTML
      .replaceAll("__DISH_INDEX__", dishIndex)
      .replaceAll("__DISH_NUMBER__", this.dishTargets.length + 1)

    this.dishesTarget.insertAdjacentHTML("beforeend", html)
    this.refreshDishControls()
  }

  removeDish(event) {
    const dish = event.target.closest("[data-meal-plan-form-target='dish']")
    if (!dish || (!this.allowEmptyDishesValue && this.dishTargets.length <= 1)) return
    if (this.confirmDishRemovalValue && !window.confirm("この料理を削除しますか？")) return

    const dishes = this.dishTargets
    const index = dishes.indexOf(dish)
    const nextFocusTarget =
      dishes[index + 1]?.querySelector("input[type='text']") ||
      dishes[index - 1]?.querySelector("input[type='text']") ||
      (this.hasAddDishButtonTarget ? this.addDishButtonTarget : null)

    dish.remove()
    this.refreshDishControls()
    nextFocusTarget?.focus()
  }

  addIngredient(event) {
    const dish = event.target.closest("[data-meal-plan-form-target='dish']")
    const ingredients = dish.querySelector("[data-meal-plan-form-target='ingredients']")
    const dishIndex = dish.dataset.dishIndex
    const ingredientIndex = this.nextIngredientIndex(dish)
    const html = this.ingredientTemplateTarget.innerHTML
      .replaceAll("__DISH_INDEX__", dishIndex)
      .replaceAll("__INGREDIENT_INDEX__", ingredientIndex)

    ingredients.insertAdjacentHTML("beforeend", html)
  }

  removeIngredient(event) {
    const ingredient = event.target.closest("[data-meal-plan-form-target='ingredient']")
    ingredient?.remove()
  }

  syncIngredientCheck(event) {
    const row = event.target.closest(".ingredient-field")
    const checkbox = row.querySelector("input[type='checkbox']")

    checkbox.checked = event.target.value.trim().length > 0
  }

  preventEmptyIngredientCheck(event) {
    const row = event.target.closest(".ingredient-field")
    const input = row.querySelector("input[type='text']")

    if (input.value.trim().length === 0) {
      event.target.checked = false
    }
  }

  nextDishIndex() {
    const indexes = this.dishTargets.map((dish) => Number(dish.dataset.dishIndex))
    return indexes.length > 0 ? Math.max(...indexes) + 1 : 0
  }

  nextIngredientIndex(dish) {
    const inputs = dish.querySelectorAll(".ingredient-field input[type='text']")
    const indexes = Array.from(inputs).map((input) => {
      const match = input.name.match(/\[ingredients\]\[(\d+)\]/)
      return match ? Number(match[1]) : 0
    })

    return indexes.length > 0 ? Math.max(...indexes) + 1 : 0
  }

  refreshDishControls() {
    this.dishTargets.forEach((dish, index) => {
      dish.querySelector("[data-meal-plan-form-target='dishNumber']").textContent = index + 1
      dish.querySelectorAll("[data-meal-plan-form-target='removeDishButton']").forEach((button) => {
        button.hidden = !this.allowEmptyDishesValue && index === 0
      })
    })
  }

  refreshDishNumbers() {
    this.dishNumberTargets.forEach((target, index) => {
      target.textContent = index + 1
    })
  }
}
