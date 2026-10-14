import { Controller } from "@hotwired/stimulus"

// Adds and removes rows of a season's episode fields, numbering each new row after the highest so far.
export default class extends Controller {
  static targets = [ "list", "template", "row", "number" ]

  add() {
    const nextNumber = Math.max(0, ...this.numberTargets.map((input) => Number(input.value) || 0)) + 1
    const index = `${Date.now()}${this.rowTargets.length}`

    this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML.replaceAll("NEW_EPISODE", index))

    const row = this.rowTargets.at(-1)
    row.querySelector("[data-episode-fields-target~='number']").value = nextNumber
    row.querySelector("input[type='text']").focus()
  }

  remove(event) {
    event.target.closest("[data-episode-fields-target~='row']").remove()
  }
}
