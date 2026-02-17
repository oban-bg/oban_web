import {
  BarController,
  BarElement,
  CategoryScale,
  Chart,
  LinearScale,
  Tooltip,
} from "chart.js"

import { GRAY, STATE_COLORS } from "../lib/colors"

Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip)

const WAIT_COLOR = "#94a3b8" // slate-400

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

const JobHistoryChart = {
  mounted() {
    const canvas = document.createElement("canvas")
    this.el.appendChild(canvas)

    this.currentJobId = parseInt(this.el.dataset.currentJobId, 10)

    this.chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: [],
        datasets: [
          {
            label: "Wait",
            data: [],
            backgroundColor: [],
            borderRadius: { topLeft: 0, topRight: 0, bottomLeft: 2, bottomRight: 2 },
            barPercentage: 0.9,
            categoryPercentage: 0.9,
          },
          {
            label: "Exec",
            data: [],
            backgroundColor: [],
            borderRadius: { topLeft: 2, topRight: 2, bottomLeft: 0, bottomRight: 0 },
            barPercentage: 0.9,
            categoryPercentage: 0.9,
          },
        ],
      },
      options: {
        animation: false,
        maintainAspectRatio: false,
        responsive: true,
        onClick: (event, elements) => {
          if (elements.length > 0) {
            const idx = elements[0].index
            const jobId = this.data[idx].id
            const basePath = window.location.pathname.replace(/\/\d+$/, "")
            window.location.href = `${basePath}/${jobId}`
          }
        },
        onHover: (event, elements) => {
          event.native.target.style.cursor =
            elements.length > 0 ? "pointer" : "default"
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            mode: "index",
            intersect: false,
            callbacks: {
              title: (context) => {
                const idx = context[0].dataIndex
                const job = this.data[idx]
                const time = formatTime(parseInt(context[0].label, 10))
                const current = job.current ? " (current)" : ""
                return `${time}${current}`
              },
              label: (context) => {
                const duration = formatDuration(context.raw)
                return `${context.dataset.label}: ${duration}`
              },
              afterBody: (context) => {
                const idx = context[0].dataIndex
                const job = this.data[idx]
                const total = job.wait_time + job.exec_time
                return `Total: ${formatDuration(total)}`
              },
            },
          },
        },
        scales: {
          x: {
            stacked: true,
            display: true,
            grid: { display: false },
            ticks: {
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
            stacked: true,
            display: true,
            beginAtZero: true,
            ticks: {
              callback: (value) => formatDuration(value),
            },
          },
        },
      },
    })

    this.handleEvent("job-history", ({ history }) => {
      this.data = history

      this.chart.data.labels = history.map((point) => point.timestamp)

      // Wait time dataset (bottom)
      this.chart.data.datasets[0].data = history.map((point) => point.wait_time)
      this.chart.data.datasets[0].backgroundColor = history.map((point) => {
        return point.current ? WAIT_COLOR : this.fadeColor(WAIT_COLOR, 0.35)
      })

      // Exec time dataset (top)
      this.chart.data.datasets[1].data = history.map((point) => point.exec_time)
      this.chart.data.datasets[1].backgroundColor = history.map((point) => {
        const baseColor = STATE_COLORS[point.state] || GRAY
        return point.current ? baseColor : this.fadeColor(baseColor, 0.35)
      })

      this.chart.update()
    })
  },

  fadeColor(hex, opacity) {
    const r = parseInt(hex.slice(1, 3), 16)
    const g = parseInt(hex.slice(3, 5), 16)
    const b = parseInt(hex.slice(5, 7), 16)
    return `rgba(${r}, ${g}, ${b}, ${opacity})`
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },
}

export default JobHistoryChart
