import { Controller } from "@hotwired/stimulus"

// Cart Mode works without reception AFTER the page has loaded. Every local
// submission is durably queued before its UI advances. The server acknowledges
// each change separately, and 409 conflicts always require a human decision.
// No private HTML, auth tokens or cookies are cached in a service worker.
export default class extends Controller {
  static values = { state: Object }
  static targets = [
    "syncIndicator", "syncText", "retryButton", "conflictPanel", "conflictText",
    "feedback", "feedbackText", "holeNumber", "par", "secondaryLabel",
    "secondaryValue", "strokeIndex", "scoredCount", "progress", "progressFill",
    "gross", "net", "completed", "headline", "savedChip", "scoreEntry",
    "scoreButtons", "clearButton", "form", "customScore", "status", "paging",
    "matchState", "completion", "completionText", "finished"
  ]

  connect() {
    const state = this.stateValue
    this.holes = state.holes || []
    this.holeByNumber = Object.fromEntries(this.holes.map(h => [h.number, h]))
    this.serverScores = Object.fromEntries(this.holes.map(h => [h.number, h.strokes]))
    this.currentHole = state.initialHole
    this.explicitHole = !!state.explicitHole
    this.lastFeedbackHole = null
    this.queue = {}
    this.conflicts = {}
    this.syncing = false
    this.syncIssue = ""
    this.storageKey = [
      "tin-cup", "cart-scores", "v1", state.scope, state.tripId,
      state.roundId, state.playerId
    ].join(":")
    this.canQueue = this.storageAvailable()
    if (this.canQueue) this.loadQueue()
    if (!this.explicitHole) this.currentHole = this.firstOpenHole()
    this.updateView()
    this.updateIndicator()
    if (this.canQueue && navigator.onLine) this.sync()
  }

  storageAvailable() {
    try {
      const key = "tin-cup-storage-check"
      localStorage.setItem(key, "ok")
      localStorage.removeItem(key)
      return true
    } catch (_) {
      return false
    }
  }

  loadQueue() {
    try {
      const raw = localStorage.getItem(this.storageKey)
      if (!raw) return
      const parsed = JSON.parse(raw)
      if (!parsed || Array.isArray(parsed) || typeof parsed !== "object") throw Error("Invalid queue")
      for (const [number, record] of Object.entries(parsed)) {
        const hole = this.holeByNumber[Number(number)]
        if (!hole || !record || record.holeId !== hole.id) throw Error("Invalid hole record")
        if (!this.validStrokes(record.strokes) || !this.validStrokes(record.expected)) throw Error("Invalid score")
        if (typeof record.nonce !== "string") throw Error("Invalid queue record")
        // A request may have reached Rails while the acknowledgement was lost.
        // Never resubmit a change that's already reflected in the server card.
        if (this.serverScores[number] === record.strokes) continue
        this.queue[number] = record
        if (this.serverScores[number] !== record.expected) {
          this.conflicts[number] = this.serverScores[number]
        }
      }
      this.persistQueue()
    } catch (_) {
      this.canQueue = false
      this.syncIssue = "stored-data"
      // Never delete corrupted data: it may contain unsynced scores.
    }
  }

  validStrokes(value) {
    return value === null || (Number.isInteger(value) && value >= 1 && value <= 30)
  }

  persistQueue() {
    try {
      if (Object.keys(this.queue).length) {
        localStorage.setItem(this.storageKey, JSON.stringify(this.queue))
      } else {
        localStorage.removeItem(this.storageKey)
      }
      return true
    } catch (_) {
      this.syncIssue = "storage"
      return false
    }
  }

  storageChanged(event) {
    if (event.key !== this.storageKey || this.syncing || !this.canQueue) return
    this.loadQueue()
    this.updateView()
    this.updateIndicator()
    this.sync()
  }

  // Intercept only the hole links inside this same card. Switching golfers
  // still uses normal Rails navigation so permissions and identity stay intact.
  jump(event) {
    if (!this.canQueue || !this.hasFormTarget) return
    const link = event.target.closest("a[data-cart-hole]")
    if (!link || !this.element.contains(link)) return
    const number = Number.parseInt(link.dataset.cartHole, 10)
    if (!this.holeByNumber[number] || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0) return
    event.preventDefault()
    this.navigate(number, true)
  }

  score(event) {
    if (!this.canQueue) return // Standard Rails form remains a safe online fallback.
    const submitter = event.submitter
    if (!submitter) return
    const hole = this.holeByNumber[this.currentHole]
    if (!hole) return

    let strokes
    if (submitter.name === "save_custom") {
      const typed = this.customScoreTarget.value.trim()
      strokes = /^[0-9]+$/.test(typed) ? Number(typed) : NaN
    } else if (submitter.name === "strokes[" + this.stateValue.playerId + "]") {
      strokes = submitter.value === "" ? null : Number(submitter.value)
    } else {
      return
    }

    event.preventDefault()
    if (!this.validStrokes(strokes) || (strokes !== null && !Number.isInteger(strokes))) {
      this.statusTarget.textContent = "Enter a gross score from 1 to 30."
      return
    }
    if (strokes === null && !window.confirm("Clear the saved score for hole " + hole.number + "?")) return

    const prior = this.queue[hole.number]
    const previous = prior || null
    const entry = {
      holeId: hole.id,
      strokes,
      expected: prior ? prior.expected : this.serverScores[hole.number],
      nonce: Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)
    }
    this.queue[hole.number] = entry
    if (!this.persistQueue()) {
      if (previous) this.queue[hole.number] = previous
      else delete this.queue[hole.number]
      this.canQueue = false
      this.statusTarget.textContent = "Device storage unavailable. This score was not saved. Try again with a connection."
      this.updateIndicator()
      return
    }

    delete this.conflicts[hole.number]
    this.syncIssue = ""
    this.lastFeedbackHole = hole.number
    this.announceScore(hole, strokes, false)
    if (strokes === null) this.navigate(hole.number, true)
    else if (hole.number < 18) this.navigate(hole.number + 1, false)
    else this.navigate(18, false)

    this.updateIndicator()
    this.sync()
  }

  navigate(number, explicit) {
    if (!this.holeByNumber[number]) return
    this.currentHole = number
    this.explicitHole = explicit
    const url = this.stateValue.cartPath + (explicit ? "&hole=" + number : "")
    // Replace instead of pushing 18 entries into the browser history.
    history.replaceState(history.state, "", url)
    this.updateView()
  }

  currentScore(number) {
    const record = this.queue[number]
    return record ? record.strokes : this.serverScores[number]
  }

  firstOpenHole() {
    return this.holes.find(h => this.currentScore(h.number) === null)?.number || 18
  }

  scoresCount() {
    return this.holes.filter(h => this.currentScore(h.number) !== null).length
  }

  formatToPar(value) {
    return value > 0 ? "+" + value : value === 0 ? "E" : String(value)
  }

  strokesReceived(handicap, index) {
    // Matches Ruby Integer#div and modulo for plus handicaps.
    return Math.floor(handicap / 18) + (index <= ((handicap % 18) + 18) % 18 ? 1 : 0)
  }

  labelFor(score, par) {
    if (score === 1) return "ACE"
    const delta = score - par
    return { "-3": "ALBATROSS", "-2": "EAGLE", "-1": "BIRDIE",
      "0": "PAR", "1": "BOGEY", "2": "DOUBLE", "3": "TRIPLE" }[delta] ||
      (delta > 0 ? "+" + delta : String(delta))
  }

  updateView() {
    const hole = this.holeByNumber[this.currentHole]
    if (!hole) return
    const count = this.scoresCount()
    this.holeNumberTarget.textContent = String(hole.number).padStart(2, "0")
    this.parTarget.textContent = String(hole.par)
    this.secondaryLabelTarget.textContent = hole.yardage ? "YARDS" : "STROKE INDEX"
    this.secondaryValueTarget.textContent = String(hole.yardage || hole.strokeIndex)
    this.strokeIndexTarget.textContent = "HCP INDEX " + hole.strokeIndex
    this.strokeIndexTarget.hidden = !hole.yardage
    this.scoredCountTarget.textContent = String(count)
    this.completedTarget.textContent = String(count)
    const percent = Math.round((count / 18) * 100)
    this.progressTarget.setAttribute("aria-valuenow", String(percent))
    this.progressFillTarget.style.width = percent + "%"
    let gross = 0
    let net = 0
    for (const entry of this.holes) {
      const score = this.currentScore(entry.number)
      if (score !== null) {
        gross += score - entry.par
        net += score - entry.par - this.strokesReceived(this.stateValue.handicap, entry.strokeIndex)
      }
    }
    this.grossTarget.textContent = count ? this.formatToPar(gross) : "—"
    this.netTarget.textContent = count ? this.formatToPar(net) : "—"

    this.element.querySelectorAll("a[data-cart-hole]").forEach(link => {
      const n = Number(link.dataset.cartHole)
      const saved = this.currentScore(n) !== null
      link.classList.toggle("active", n === hole.number)
      link.classList.toggle("recorded", saved)
      link.classList.toggle("cart-hole-pending", !!this.queue[n])
      if (n === hole.number) link.setAttribute("aria-current", "page")
      else link.removeAttribute("aria-current")
      link.setAttribute("aria-label", "Hole " + n + (saved ? ", recorded" : ", not scored") + (this.queue[n] ? ", awaiting sync" : ""))
    })
    const isComplete = count === 18 && !this.explicitHole
    if (this.hasScoreEntryTarget) this.scoreEntryTarget.hidden = isComplete
    if (this.hasCompletionTarget) {
      this.completionTarget.hidden = !isComplete || this.hasFinishedTarget
      const pending = Object.keys(this.queue).length
      this.completionTextTarget.textContent = pending
        ? count + " holes recorded. " + pending + " score" + (pending === 1 ? "" : "s") + " still waiting to sync to the leaderboard."
        : "Every hole is synchronized to Tin Cup. Your round is official."
    }

    if (!this.hasFormTarget) return
    this.formTarget.action = hole.postPath
    const current = this.currentScore(hole.number)
    this.headlineTarget.textContent = current === null ? "How'd you do?" : "Change your score."
    this.savedChipTarget.hidden = current === null
    this.savedChipTarget.textContent = current === null ? "" : (this.queue[hole.number] ? "◷ HELD ON DEVICE " : "✓ SAVED ") + current
    this.clearButtonTarget.hidden = current === null
    this.statusTarget.textContent = ""
    this.customScoreTarget.value = ""
    this.createButtons(hole, current)
    this.createPaging(hole.number)
    this.showConflict()
  }

  createButtons(hole, current) {
    const buttons = []
    for (let score = hole.par - 2; score <= hole.par + 4; score++) {
      if (score < 1 || score > 30) continue
      const label = this.labelFor(score, hole.par)
      const button = document.createElement("button")
      button.type = "submit"
      button.name = "strokes[" + this.stateValue.playerId + "]"
      button.value = String(score)
      button.className = "cart-score-button" +
        (label === "PAR" ? " is-par" : "") +
        (current === score ? " is-saved" : "")
      button.setAttribute("aria-label", "Score " + score + " strokes, " + label.toLowerCase() + ", hole " + hole.number)
      const numeral = document.createElement("strong")
      numeral.textContent = String(score)
      const caption = document.createElement("span")
      caption.textContent = label
      button.append(numeral, caption)
      buttons.push(button)
    }
    this.scoreButtonsTarget.replaceChildren(...buttons)
  }

  createPaging(n) {
    const links = []
    for (const target of [n - 1, n + 1]) {
      if (target < 1 || target > 18) continue
      const link = document.createElement("a")
      link.href = this.stateValue.cartPath + "&hole=" + target
      link.dataset.cartHole = String(target)
      link.textContent = target < n ? "← Hole " + target : "Skip to hole " + target + " →"
      links.push(link)
    }
    this.pagingTarget.replaceChildren(...links)
  }

  announceScore(hole, strokes, synced) {
    const adjective = strokes === null ? "Score cleared" : this.labelFor(strokes, hole.par)
    let moment = ""
    if (strokes !== null && strokes < hole.par) {
      moment = " • Nice work!"
      const previous = hole.number > 1 ? this.currentScore(hole.number - 1) : null
      const previousHole = this.holeByNumber[hole.number - 1]
      if (previous !== null && previousHole && previous < previousHole.par) {
        moment = " • Back-to-back red numbers!"
      }
    }
    if (hole.number === 9 && this.holes.slice(0, 9).every(h => this.currentScore(h.number) !== null)) moment = " • Front nine complete!"
    this.feedbackTextTarget.textContent = (strokes === null ? adjective : adjective + " on " + hole.number) +
      " · " + (synced ? "synced to Tin Cup" : "saved on this device") + moment
    this.feedbackTarget.classList.toggle("cart-local-highlight", strokes !== null && strokes < hole.par)
    this.feedbackTarget.hidden = false
    const earlier = this.element.querySelector(".cart-toast:not(.cart-local-toast)")
    if (earlier) earlier.hidden = true
  }

  editLast() {
    if (this.lastFeedbackHole) this.navigate(this.lastFeedbackHole, true)
  }

  updateIndicator() {
    if (!this.canQueue) {
      this.syncIndicatorTarget.hidden = false
      this.syncIndicatorTarget.className = "cart-sync-indicator cart-sync-warning"
      this.syncTextTarget.textContent = this.syncIssue === "stored-data"
        ? "Saved scores on this device couldn't be read. Nothing was deleted. Use the full scorecard and contact support before clearing site data."
        : "Offline saving is unavailable in this browser. You need a connection to save."
      this.retryButtonTarget.hidden = true
      return
    }
    const pending = Object.keys(this.queue).length
    const conflictCount = Object.keys(this.conflicts).length
    this.syncIndicatorTarget.hidden = false
    this.syncIndicatorTarget.className = "cart-sync-indicator " +
      (conflictCount ? "cart-sync-warning" : pending ? "cart-sync-pending" : "cart-sync-ok")
    if (conflictCount) {
      this.syncTextTarget.textContent = conflictCount + " hole" + (conflictCount === 1 ? "" : "s") +
        " need a score decision before syncing. Your device copy is safe."
    } else if (pending && !navigator.onLine) {
      this.syncTextTarget.textContent = "OFFLINE · " + pending + " score" + (pending === 1 ? "" : "s") +
        " saved on this device. Keep this page open; we'll retry on reconnect."
    } else if (pending && this.syncIssue === "authentication") {
      this.syncTextTarget.textContent = "Sign-in required to sync " + pending + " saved score" + (pending === 1 ? "" : "s") + "."
    } else if (pending) {
      this.syncTextTarget.textContent = this.syncing ? "Syncing " + pending + " score" + (pending === 1 ? "" : "s") + "…" :
        pending + " score" + (pending === 1 ? "" : "s") + " saved on this device · awaiting sync."
    } else {
      this.syncTextTarget.textContent = navigator.onLine ? "✓ All scores synced to Tin Cup" : "OFFLINE · No unsynced scores"
    }
    this.retryButtonTarget.hidden = !pending || !navigator.onLine
    this.showConflict()
  }

  showConflict() {
    if (!this.hasConflictPanelTarget) return
    const first = Object.keys(this.conflicts).map(Number).sort((a, b) => a - b)[0]
    this.conflictPanelTarget.hidden = !first
    if (first) {
      const server = this.conflicts[first]
      const local = this.queue[first]?.strokes
      this.conflictTextTarget.textContent = "Hole " + first + ": server has " +
        (server === null ? "no score" : server + " strokes") + "; this device has " +
        (local === null ? "no score" : local + " strokes") + ". Choose which to keep."
      this.conflictHole = first
    }
  }

  keepDevice() {
    const number = this.conflictHole
    const entry = this.queue[number]
    if (!entry) return
    entry.expected = this.conflicts[number]
    if (!this.persistQueue()) return
    delete this.conflicts[number]
    this.syncIssue = ""
    this.updateIndicator()
    this.sync()
  }

  keepServer() {
    const number = this.conflictHole
    if (!this.queue[number]) return
    this.serverScores[number] = this.conflicts[number]
    delete this.conflicts[number]
    delete this.queue[number]
    if (!this.persistQueue()) return
    this.updateView()
    this.updateIndicator()
    this.sync()
  }

  retry() {
    if (this.canQueue) this.sync()
  }

  async sync() {
    if (!this.canQueue || this.syncing || !navigator.onLine || !Object.keys(this.queue).length) {
      this.updateIndicator()
      return
    }
    this.syncing = true
    this.updateIndicator()
    try {
      for (const number of Object.keys(this.queue).map(Number).sort((a, b) => a - b)) {
        if (this.conflicts[number]) continue
        const entry = this.queue[number]
        if (!entry) continue
        const hole = this.holeByNumber[number]
        const body = new URLSearchParams()
        body.set("_method", "patch")
        body.set("cart_mode", "1")
        body.set("cart_sync", "1")
        body.set("player_id", String(this.stateValue.playerId))
        body.set("cart_expected_strokes", entry.expected === null ? "blank" : String(entry.expected))
        body.set("strokes[" + this.stateValue.playerId + "]", entry.strokes === null ? "" : String(entry.strokes))
        let response
        try {
          response = await fetch(hole.postPath, {
            method: "POST", credentials: "same-origin",
            headers: {
              "Accept": "application/json",
              "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
              "X-Requested-With": "XMLHttpRequest",
              "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content || ""
            },
            body: body.toString()
          })
        } catch (_) {
          this.syncIssue = "network"
          break
        }
        if (response.status === 409) {
          const conflict = await response.json()
          this.conflicts[number] = conflict.server_strokes
          this.syncIssue = "conflict"
          continue
        }
        if (!response.ok || !response.headers.get("content-type")?.includes("application/json")) {
          this.syncIssue = response.redirected || response.status === 401 || response.status === 403
            ? "authentication" : "server"
          break
        }
        const confirmed = await response.json()
        this.serverScores[number] = confirmed.strokes
        if (this.queue[number]?.nonce === entry.nonce) {
          delete this.queue[number]
        } else if (this.queue[number]) {
          // User edited the hole again while the previous request was in flight.
          this.queue[number].expected = confirmed.strokes
        }
        this.persistQueue()
        if (this.lastFeedbackHole === number && !this.queue[number]) {
          this.announceScore(hole, confirmed.strokes, true)
        }
        if (confirmed.match) this.renderMatch(confirmed.match)
        this.syncIssue = ""
        this.updateView()
      }
    } finally {
      this.syncing = false
      this.updateView()
      this.updateIndicator()
    }
  }

  renderMatch(match) {
    if (!this.hasMatchStateTarget) return
    const wrapper = this.matchStateTarget
    const heading = wrapper.querySelector("strong")
    const detail = wrapper.querySelector("small")
    if (!heading || !detail) return
    heading.textContent = match.status === "scheduled" ? "NOT STARTED" :
      !match.leader_name ? "ALL SQUARE" : match.margin + " UP" + (match.status === "final" ? " · FINAL" : "")
    detail.textContent = (match.leader_name || (match.status === "scheduled" ? "First tee awaits" : "Tied")) +
      (match.through ? " · Thru " + match.through : "")
  }
}
