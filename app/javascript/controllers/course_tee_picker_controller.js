import { Controller } from "@hotwired/stimulus"

// Reacts to selecting a saved course without another full-page navigation.
// A tee selection is optional; the scorecard's par/stroke index is unchanged.
export default class extends Controller {
  static targets = ["course", "tee"]
  static values = { map: Object, selected: String }

  connect() {
    this.update()
  }

  update() {
    const options = this.mapValue[this.courseTarget.value] || []
    const old = this.teeTarget.value || this.selectedValue
    this.teeTarget.replaceChildren()
    const blank = new Option(options.length ? "Select a tee box (optional)" : "Tee boxes unavailable", "")
    this.teeTarget.add(blank)
    options.forEach(name => this.teeTarget.add(new Option(name, name)))
    if (options.includes(old)) this.teeTarget.value = old
    this.selectedValue = ""
  }
}
