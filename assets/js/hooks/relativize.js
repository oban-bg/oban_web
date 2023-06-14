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
  const ellapsed = Math.floor(Math.abs(Date.now() - timestamp) / 1000)

  let distance = ""

  if (ellapsed === 0) distance = "now"
  else if (ellapsed <= 59) distance = `${ellapsed}s`
  else if (ellapsed <= 3_599) distance = `${Math.floor(ellapsed / 60)}m`
  else if (ellapsed <= 86_399) distance = `${Math.floor(ellapsed / 3_600)}h`
  else if (ellapsed <= 2_591_999) distance = `${Math.floor(ellapsed / 86_400)}d`
  else if (ellapsed <= 31_535_999) distance = `${Math.floor(ellapsed / 2_592_000)}mo`
  else distance = `${Math.floor(ellapsed / 31536000)}yr`

  if (ellapsed < 0) return `${distance} ago`
  if (ellapsed > 0) return `in ${distance}`

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

    this.interval = window.setInterval(setter, 1000)
  },
}

export default Relavitize
