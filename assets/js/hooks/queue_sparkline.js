import tippy, { followCursor, roundArrow } from "tippy.js"
import { CYAN } from "../lib/colors"

const formatTime = (timestamp) => {
  const date = new Date(timestamp)
  return date.toLocaleString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    second: "2-digit",
    hour12: true,
  })
}

const QueueSparkline = {
  mounted() {
    this.initData()
  },

  updated() {
    this.initData()
  },

  initData() {
    this.data = JSON.parse(this.el.dataset.tooltip)
    this.barWidth = parseInt(this.el.dataset.barWidth, 10)
    this.step = this.barWidth + 1 // bar width + gap

    // Get all the bar rects (skip placeholders which have height="2")
    this.bars = Array.from(this.el.querySelectorAll("rect")).filter(
      (rect) => rect.getAttribute("height") !== "2"
    )

    // Build a map from slot position to bar element for sparse data
    this.barsBySlot = new Map()
    this.bars.forEach((bar) => {
      const x = parseInt(bar.getAttribute("x"), 10)
      const slot = Math.floor(x / this.step)
      this.barsBySlot.set(slot, bar)
    })

    if (this.tippy) return // Already initialized

    this.tippy = tippy(this.el, {
      arrow: roundArrow,
      content: "",
      delay: [50, 0],
      duration: [200, 0],
      followCursor: "horizontal",
      plugins: [followCursor],
      placement: "top",
      allowHTML: true,
      trigger: "manual",
    })

    this.lastSlot = null

    this.el.addEventListener("mousemove", (event) => {
      const rect = this.el.getBoundingClientRect()
      const x = event.clientX - rect.left
      const slot = Math.floor(x / this.step)

      // Clear previous highlight
      if (this.lastSlot !== null && this.lastSlot !== slot) {
        const prevBar = this.barsBySlot.get(this.lastSlot)
        if (prevBar) prevBar.style.opacity = "1"
      }

      if (slot >= 0 && slot < this.data.length) {
        const point = this.data[slot]
        const countLabel = point.count === 1 ? "job" : "jobs"
        const content = `
          <span style="color: ${CYAN}; font-weight: 600;">${point.count}</span>
          <span style="color: #9ca3af;"> ${countLabel}</span>
          <span style="color: #9ca3af; margin-left: 4px;">${formatTime(point.timestamp)}</span>
        `
        this.tippy.setContent(content)
        this.tippy.show()

        // Highlight current bar if it exists, dim others
        this.bars.forEach((bar) => {
          const barSlot = Math.floor(parseInt(bar.getAttribute("x"), 10) / this.step)
          bar.style.opacity = barSlot === slot ? "1" : "0.4"
        })
        this.lastSlot = slot
      } else {
        this.tippy.hide()
        // Reset all bars
        this.bars.forEach((bar) => (bar.style.opacity = "1"))
        this.lastSlot = null
      }
    })

    this.el.addEventListener("mouseleave", () => {
      this.tippy.hide()
      // Reset all bars
      this.bars.forEach((bar) => (bar.style.opacity = "1"))
      this.lastSlot = null
    })
  },

  destroyed() {
    if (this.tippy) {
      this.tippy.destroy()
    }
  },
}

export default QueueSparkline
