import { load, store } from "../lib/settings"

import {
  BarController,
  BarElement,
  CategoryScale,
  Chart,
  Legend,
  LinearScale,
  LineController,
  LineElement,
  PointElement,
  Tooltip,
} from "chart.js"

Chart.register(
  BarController,
  BarElement,
  CategoryScale,
  Legend,
  LineController,
  LineElement,
  LinearScale,
  PointElement,
  Tooltip,
)

Chart.defaults.font.size = 12
Chart.defaults.font.family = "Inter var"

const CYAN = "#22d3ee" // cyan-400
const EMERALD = "#34d399" // emerald-400
const ORANGE = "#fb923c" // orange-400
const ROSE = "#fb7185" // rose-400
const TEAL = "#2dd4bf" // teal-500
const VIOLET = "#a78bfa" // violet-400
const YELLOW = "#facc15" // yellow-400

const OTHER_PALETTE = [CYAN, VIOLET, YELLOW, EMERALD, ORANGE, TEAL, ROSE]

const STATE_PALETTE = {
  available: TEAL,
  completed: CYAN,
  cancelled: VIOLET,
  discarded: ROSE,
  executing: ORANGE,
  retryable: YELLOW,
  scheduled: EMERALD,
}

const STORABLE = ["group", "ntile", "period", "series", "visible"]

const storeChanges = (changes) => {
  for (const [key, val] of Object.entries(changes)) {
    if (STORABLE.includes(key) && val !== undefined) {
      store(`chart-${key}`, val)
    }
  }
}

const estimateCount = function (value) {
  let base
  let mult
  let powr
  let suff

  if (value < 1000) {
    return value
  } else if (value < 10_000) {
    mult = Math.pow(10, 3)
    base = Math.floor(value / mult)
    part = Math.round((value % mult) / Math.pow(10, 2))

    if (part === 0) {
      return `${base}k`
    } else if (part === 10) {
      return `${base + 1}k`
    } else {
      return `${base}.${part}k`
    }
  } else if (value < 1_000_000) {
    powr = 3
    suff = "k"
  } else if (value < 1_000_000_000) {
    powr = 6
    suff = "m"
  } else {
    powr = 9
    suff = "b"
  }

  base = Math.round(value / Math.pow(10, powr))

  return `${base}${suff}`
}

const estimateNanos = function (value) {
  const milliseconds = value / 1e6
  const seconds = value / 1e9
  const minutes = value / 6e10
  const hours = value / 3.6e12

  if (hours >= 1) {
    return `${hours.toFixed(1)}h`
  } else if (minutes >= 1) {
    return `${minutes.toFixed(1)}m`
  } else if (seconds >= 1) {
    return `${seconds.toFixed(1)}s`
  } else if (milliseconds >= 1000) {
    return `${milliseconds.toFixed(1)}ms`
  } else {
    return `${milliseconds.toFixed(0)}ms`
  }
}

const liner = {
  id: "verticalLiner",
  afterInit: (chart, args, opts) => {
    chart.verticalLiner = {}
  },
  afterEvent: (chart, args, options) => {
    const { inChartArea } = args
    chart.verticalLiner = { draw: inChartArea }
  },
  beforeTooltipDraw: (chart, args, options) => {
    const { draw } = chart.verticalLiner

    if (!draw) return

    const { ctx } = chart
    const { top, bottom } = chart.chartArea
    const { tooltip } = args
    const x = tooltip?.caretX

    if (!x) return

    ctx.save()

    ctx.beginPath()
    ctx.moveTo(x, top)
    ctx.lineTo(x, bottom)
    ctx.strokeStyle = "#d1d5db" // gray-300
    ctx.globalCompositeOperation = "destination-over"
    ctx.stroke()

    ctx.restore()
  },
}

const BASIC_OPTS = {
  animation: false,
  maintainAspectRatio: false,
  normalized: true,
  responsive: true,
  resizeDelay: 100,
  interaction: {
    mode: "index",
    intersect: false,
  },
  layout: {
    padding: {
      bottom: 4,
    },
  },
  plugins: {
    legend: {
      display: false,
    },
    verticalLiner: {},
    tooltip: {
      callbacks: {
        title: function (context) {
          const date = new Date(parseInt(context[0].label) * 1000)

          return date.toLocaleTimeString("en-US", { hour12: false, timeStyle: "long" })
        },

        label: function (context) {
          const type = context.chart.options.type
          const label = context.dataset.label
          const value = context.parsed.y || 0

          if (type === "line") {
            return `${label}: ${estimateNanos(value)}`
          } else {
            return `${label}: ${estimateCount(value)}`
          }
        },
      },
    },
  },
}

const STACK_OPTS = {
  ...BASIC_OPTS,
  scales: {
    x: {
      stacked: true,
      grid: {
        display: false,
        drawTicks: true,
      },
      ticks: {
        maxRotation: 0,
        minRotation: 0,
        padding: 3,
        callback: function (value, index) {
          if (index % 4 === 0) {
            const date = new Date(parseInt(this.getLabelForValue(value)) * 1000)

            return date.toLocaleTimeString("en-US", { hour12: false, timeStyle: "medium" })
          }
        },
      },
    },
    y: {
      stacked: true,
      ticks: {
        callback: function (value, index, _ticks) {
          if (index % 2 === 0) return estimateCount(value)
        },
      },
    },
  },
}

const LINES_OPTS = {
  ...BASIC_OPTS,
  borderWidth: 2,
  borderJoinStyle: "round",
  radius: 2,
  spanGaps: true,
  scales: {
    x: {
      grid: {
        display: false,
      },
      ticks: {
        maxRotation: 0,
        minRotation: 0,
        padding: 3,
        callback: function (value, index) {
          if (index % 4 === 0) {
            const date = new Date(parseInt(this.getLabelForValue(value)) * 1000)

            return date.toLocaleTimeString("en-US", { hour12: false, timeStyle: "medium" })
          }
        },
      },
    },
    y: {
      ticks: {
        callback: function (value, index, _ticks) {
          if (index % 2 === 0) return estimateNanos(value)
        },
      },
    },
  },
}

const Charter = {
  mounted() {
    let chart = null

    this.handleEvent("chart-change", (changes) => {
      const { group, points, series } = changes

      storeChanges(changes)

      const [type, opts] = /_count/.test(series) ? ["bar", STACK_OPTS] : ["line", LINES_OPTS]
      const plugins = type === "line" ? [liner] : []

      if (chart === null) {
        chart = new Chart(this.el, { type: type, options: opts, plugins: plugins })
      } else if (chart.config.type !== type) {
        chart.destroy()
        chart = new Chart(this.el, { type: type, options: opts, plugins: plugins })
      }

      const datasets = Object.entries(points).map(([label, data], index) => {
        const color = group === "state" ? STATE_PALETTE[label] : OTHER_PALETTE[index]

        return {
          backgroundColor: color,
          barPercentage: 1.0,
          barThickness: "flex",
          borderColor: color,
          data: data.reverse(),
          label: label,
        }
      })

      chart.data.datasets = datasets
      chart.update()
    })
  },
}

export default Charter
