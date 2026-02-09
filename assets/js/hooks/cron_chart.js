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

const parseHistory = (el, history = null) => {
  const data = history || JSON.parse(el.dataset.history)
  const now = Date.now()

  return {
    data: data,
    labels: data.map((job) => job.finished_at || job.attempted_at),
    durations: data.map((job) => {
      if (!job.attempted_at) return 0
      const start = new Date(job.attempted_at)
      const end = job.finished_at ? new Date(job.finished_at) : now
      return end - start
    }),
    colors: data.map((job) => STATE_COLORS[job.state] || GRAY),
  }
}

const CronChart = {
  mounted() {
    const canvas = document.createElement("canvas")
    this.el.appendChild(canvas)

    const { data, labels, durations, colors } = parseHistory(this.el)
    this.data = data

    this.chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: labels,
        datasets: [
          {
            data: durations,
            backgroundColor: colors,
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
              title: (context) => formatTime(context[0].label),
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
              maxRotation: 0,
              autoSkip: true,
              maxTicksLimit: 6,
              callback: function (value, index) {
                const label = this.getLabelForValue(value)
                const date = new Date(label)
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
            ticks: {
              callback: (value) => formatDuration(value),
            },
          },
        },
      },
    })

    this.handleEvent("cron-history", ({ history }) => {
      const { data, labels, durations, colors } = parseHistory(this.el, history)
      this.data = data

      this.chart.data.labels = labels
      this.chart.data.datasets[0].data = durations
      this.chart.data.datasets[0].backgroundColor = colors
      this.chart.update()
    })
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },
}

export default CronChart
