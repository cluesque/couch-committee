import { Controller } from "@hotwired/stimulus"

// Sets a date field to today in the browser's own time zone. The server's "today" is UTC, which is
// already tomorrow on a US evening.
export default class extends Controller {
  connect() {
    const now = new Date()
    const pad = (number) => String(number).padStart(2, "0")
    this.element.value = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
  }
}
