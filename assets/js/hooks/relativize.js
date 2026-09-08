import { load } from "../lib/settings"

function pad(number) {
  return number < 10 ? `0${number}` : number
}

function missing(timestamp) {
  return timestamp == null || timestamp === "" || !Number.isFinite(Number(timestamp))
}

function toDuration(timestamp) {
  if (missing(timestamp)) return "-"

  const ellapsed = Math.floor(Math.abs(Date.now() - timestamp) / 1000)
  const seconds = ellapsed % 60
  const minutes = Math.floor((ellapsed % 3600) / 60)
  const hours = Math.floor(ellapsed / 3600)
  const parts = [pad(minutes), pad(seconds)]

  if (hours > 0) {
    parts.unshift(pad(hours))
  }

  return parts.join(":")
}

function toWords(timestamp) {
  if (missing(timestamp)) return "-"

  const ellapsed = Date.now() - timestamp
  const relative = Math.floor(Math.abs(ellapsed) / 1000)

  if (relative === 0) return "now"

  let distance = ""

  if (relative <= 59) distance = `${relative}s`
  else if (relative <= 3_599) distance = `${Math.floor(relative / 60)}m`
  else if (relative <= 86_399) distance = `${Math.floor(relative / 3_600)}h`
  else if (relative <= 2_591_999) distance = `${Math.floor(relative / 86_400)}d`
  else if (relative <= 31_535_999) distance = `${Math.floor(relative / 2_592_000)}mo`
  else distance = `${Math.floor(relative / 31_536_000)}yr`

  if (ellapsed > 0) return `${distance} ago`
  if (ellapsed < 0) return `in ${distance}`

  return distance
}

// Every relative timestamp on a page shares one ticker rather than owning an interval. A table
// of a hundred rows would otherwise run a hundred timers, each reading localStorage and rewriting
// text that rarely changes.
const hooks = new Set()

let ticker = null

function tick() {
  if (load("refresh") > 0) {
    for (const hook of hooks) hook.render()
  }
}

function subscribe(hook) {
  hooks.add(hook)

  if (ticker === null) ticker = window.setInterval(tick, 1000)
}

function unsubscribe(hook) {
  hooks.delete(hook)

  if (hooks.size === 0) {
    window.clearInterval(ticker)
    ticker = null
  }
}

const Relativize = {
  render() {
    const text = this.mode === "words" ? toWords(this.timestamp) : toDuration(this.timestamp)

    if (this.el.textContent !== text) this.el.textContent = text
  },

  configure() {
    this.timestamp = this.el.getAttribute("data-timestamp")
    this.mode = this.el.getAttribute("data-relative-mode") || "words"

    this.render()
  },

  mounted() {
    this.configure()

    subscribe(this)
  },

  updated() {
    this.configure()
  },

  destroyed() {
    unsubscribe(this)
  },
}

export default Relativize
