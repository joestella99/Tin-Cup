import { Controller } from "@hotwired/stimulus"

// All score selection works with plain HTML forms. This only handles
// duplicate-tap prevention and truthful network status messaging.
export default class extends Controller {
  static targets = ["status"]

  submit(event) {
    if (this.element.dataset.submitting === "true") {
      event.preventDefault()
      return
    }
    this.element.dataset.submitting = "true"
    this.element.classList.add("is-saving")
    this.statusTarget.textContent = "Saving your score…"
    // Keep the tapped submit button enabled so its score is sent in the form.
  }

  complete(event) {
    if (event.detail.success) return
    this.element.dataset.submitting = "false"
    this.element.classList.remove("is-saving")
    this.statusTarget.textContent = "Score not saved. Check your connection and try again."
  }
}
