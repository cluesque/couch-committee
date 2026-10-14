import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Drag-to-reorder a list by its items' handles. On drop, PATCHes the items' ids, in their new order,
// to the url value. If the server refuses, reload so the page shows the order that was actually kept.
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      handle: "[data-sortable-handle]",
      animation: 150,
      // Drag with pointer events rather than native HTML5 drag-and-drop: the same path touch devices
      // use, and one that synthesized mouse input (system tests) can drive.
      forceFallback: true,
      onEnd: (event) => { if (event.oldIndex !== event.newIndex) this.save() }
    })
  }

  disconnect() {
    this.sortable.destroy()
  }

  async save() {
    const ids = Array.from(this.element.children, (item) => item.dataset.sortableId)
    const headers = { "Content-Type": "application/json" }
    // Absent when forgery protection is off, as in the test environment.
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    if (csrfToken) headers["X-CSRF-Token"] = csrfToken

    const response = await fetch(this.urlValue, {
      method: "PATCH",
      headers,
      body: JSON.stringify({ list_entry_ids: ids })
    })

    if (!response.ok) window.location.reload()
  }
}
