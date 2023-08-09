import { load } from "../lib/settings"

function pad(number) {
  return number < 10 ? `0${number}` : number
}

function toDuration(timestamp) {
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

const Relavitize = {
  destroyed() {
    clearInterval(this.interval)
  },

  mounted() {
    const timestamp = this.el.getAttribute("data-timestamp")
    const mode = this.el.getAttribute("data-relative-mode") || "words"

    const setter = () => {
      this.el.textContent = mode === "words" ? toWords(timestamp) : toDuration(timestamp)
    }

    setter()

    this.interval = window.setInterval(() => {
      if (load("refresh") > 0) setter()
    }, 1000)
  },
}

export default Relavitize
