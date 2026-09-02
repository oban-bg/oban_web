import {
  BarController,
  BarElement,
  CategoryScale,
  Chart,
  LinearScale,
  Tooltip,
} from "chart.js"

import { GRAY, STATE_FG } from "../lib/colors"

Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip)

// Axis chrome follows the theme's muted and border tokens rather than Chart.js defaults, which
// are tuned for a white canvas and sink into the dark well.
const isDark = () => document.documentElement.classList.contains("dark")
const tickColor = () => (isDark() ? "#9ca3af" : "#6b7280")
const gridColor = () => (isDark() ? "#374151" : "#e5e7eb")

const formatDuration = (ms) => {
  if (ms < 1000) return `${Math.round(ms)}ms`
  if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`
  if (ms < 3600000) return `${(ms / 60000).toFixed(1)}m`
  return `${(ms / 3600000).toFixed(1)}h`
}

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

const CronChart = {
  mounted() {
    const canvas = document.createElement("canvas")
    this.el.appendChild(canvas)

    this.chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: [],
        datasets: [
          {
            data: [],
            backgroundColor: [],
            borderRadius: 2,
            barPercentage: 0.9,
            categoryPercentage: 0.9,
          },
        ],
      },
      options: {
        animation: false,
        maintainAspectRatio: false,
        responsive: true,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              title: (context) => formatTime(parseInt(context[0].label, 10)),
              label: (context) => {
                const idx = context.dataIndex
                const state = this.data[idx].state
                const duration = formatDuration(context.raw)
                return `${state}: ${duration}`
              },
            },
          },
        },
        scales: {
          x: {
            display: true,
            grid: { display: false },
            ticks: {
              color: tickColor(),
              maxRotation: 0,
              autoSkip: true,
              maxTicksLimit: 6,
              callback: function (value) {
                const timestamp = parseInt(this.getLabelForValue(value), 10)
                const date = new Date(timestamp)
                return date.toLocaleTimeString("en-US", {
                  hour: "numeric",
                  minute: "2-digit",
                  hour12: true,
                })
              },
            },
          },
          y: {
            display: true,
            beginAtZero: true,
            grid: { color: gridColor() },
            ticks: {
              color: tickColor(),
              callback: (value) => formatDuration(value),
            },
          },
        },
      },
    })

    this.themeObserver = new MutationObserver(() => this.applyTheme())
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    })

    // The first paint can land before the web font does, leaving the axes in the fallback face
    // until the next history push.
    if (document.fonts) {
      document.fonts.ready.then(() => this.chart.update())
    }

    this.handleEvent("cron-history", ({ history }) => {
      this.data = history

      this.chart.data.labels = history.map((point) => point.timestamp)
      this.chart.data.datasets[0].data = history.map((point) => point.duration)
      this.chart.data.datasets[0].backgroundColor = history.map(
        (point) => STATE_FG[point.state] || GRAY
      )
      this.chart.update()
    })
  },

  applyTheme() {
    const { x, y } = this.chart.options.scales

    x.ticks.color = tickColor()
    y.ticks.color = tickColor()
    y.grid.color = gridColor()

    this.chart.update()
  },

  destroyed() {
    if (this.themeObserver) {
      this.themeObserver.disconnect()
    }

    if (this.chart) {
      this.chart.destroy()
    }
  },
}

export default CronChart
