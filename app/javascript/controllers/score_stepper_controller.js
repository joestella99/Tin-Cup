import { Controller } from "@hotwired/stimulus"

// Empty cards start from the hole's par. The input stays editable with a keyboard.
export default class extends Controller {
  static targets = ["input"]
  static values = { par: Number }

  increment() { this.adjust(1) }
  decrement() { this.adjust(-1) }
  setPar() { this.setValue(this.parValue) }

  adjust(amount) {
    const entered = Number.parseInt(this.inputTarget.value, 10)
    const baseline = Number.isNaN(entered) ? this.parValue : entered
    this.setValue(Math.max(1, Math.min(30, baseline + amount)))
  }

  setValue(value) {
    this.inputTarget.value = String(value)
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
