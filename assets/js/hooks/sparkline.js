import tippy, { followCursor, roundArrow } from "tippy.js"
import { STATE_COLORS, GRAY } from "../lib/colors"

const formatTime = (timestamp) => {
  const date = new Date(timestamp)
  return date.toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  })
}

const Sparkline = {
  mounted() {
    this.initData()
  },

  updated() {
    this.initData()
  },

  initData() {
    this.data = JSON.parse(this.el.dataset.tooltip)
    this.barWidth = parseInt(this.el.dataset.barWidth, 10)
    this.offset = parseInt(this.el.dataset.offset, 10)
    this.step = this.barWidth + 1 // bar width + gap

    // Get all the bar rects (skip placeholders which have height="2")
    this.bars = Array.from(this.el.querySelectorAll("rect")).filter(
      (rect) => rect.getAttribute("height") !== "2"
    )

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

    this.lastIndex = null

    this.el.addEventListener("mousemove", (event) => {
      const rect = this.el.getBoundingClientRect()
      const x = event.clientX - rect.left
      const slot = Math.floor(x / this.step)
      const index = slot - this.offset

      // Clear previous highlight
      if (this.lastIndex !== null && this.lastIndex !== index) {
        const prevBar = this.bars[this.lastIndex]
        if (prevBar) prevBar.style.opacity = "1"
      }

      if (index >= 0 && index < this.data.length) {
        const point = this.data[index]
        const color = STATE_COLORS[point.state] || GRAY
        const content = `
          <span style="color: ${color}; font-weight: 600;">${point.state}</span>
          <span style="color: #9ca3af; margin-left: 4px;">${formatTime(point.timestamp)}</span>
        `
        this.tippy.setContent(content)
        this.tippy.show()

        // Highlight current bar, dim others
        this.bars.forEach((bar, i) => {
          bar.style.opacity = i === index ? "1" : "0.4"
        })
        this.lastIndex = index
      } else {
        this.tippy.hide()
        // Reset all bars
        this.bars.forEach((bar) => (bar.style.opacity = "1"))
        this.lastIndex = null
      }
    })

    this.el.addEventListener("mouseleave", () => {
      this.tippy.hide()
      // Reset all bars
      this.bars.forEach((bar) => (bar.style.opacity = "1"))
      this.lastIndex = null
    })
  },

  destroyed() {
    if (this.tippy) {
      this.tippy.destroy()
    }
  },
}

export default Sparkline
