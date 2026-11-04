import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button", "status"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
      this.statusTarget.textContent = "Copied."
    } catch {
      this.sourceTarget.focus()
      this.sourceTarget.select()
      this.statusTarget.textContent = "Select and copy the highlighted text."
    }
  }
}
