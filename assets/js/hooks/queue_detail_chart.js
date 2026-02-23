import {
  BarController,
  BarElement,
  CategoryScale,
  Chart,
  LinearScale,
  Tooltip,
} from "chart.js"

import { CYAN, GRAY } from "../lib/colors"

Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip)

const formatTime = (timestamp) => {
  const date = new Date(timestamp)
  return date.toLocaleString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  })
}

const QueueDetailChart = {
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
            backgroundColor: CYAN,
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
                const count = context.raw
                const label = count === 1 ? "job" : "jobs"
                return `${count} ${label}`
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
              maxTicksLimit: 8,
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
            ticks: {
              stepSize: 1,
              callback: (value) => (Number.isInteger(value) ? value : null),
            },
          },
        },
      },
    })

    this.handleEvent("queue-history", ({ history }) => {
      this.data = history

      this.chart.data.labels = history.map((point) => point.timestamp)
      this.chart.data.datasets[0].data = history.map((point) => point.count)
      this.chart.update()
    })
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },
}

export default QueueDetailChart
