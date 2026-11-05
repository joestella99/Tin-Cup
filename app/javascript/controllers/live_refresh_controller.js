import { Controller } from "@hotwired/stimulus"

// Refresh just the live board, without disturbing the chosen round or navigation.
export default class extends Controller {
  static values = { interval: { type: Number, default: 25000 } }

  connect() {
    this.timer = window.setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    window.clearInterval(this.timer)
  }

  refresh() {
    if (document.visibilityState === "hidden" || this.element.hasAttribute("busy")) return
    if (this.element.getAttribute("src") && typeof this.element.reload === "function") {
      this.element.reload()
    }
  }
}
