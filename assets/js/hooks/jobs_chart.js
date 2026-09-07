import { store } from "../lib/settings"
import { LINE_FG } from "../lib/colors"

import {
  BarController,
  BarElement,
  CategoryScale,
  Chart,
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
  LineController,
  LineElement,
  LinearScale,
  PointElement,
  Tooltip,
)

Chart.defaults.font.size = 12
Chart.defaults.font.family = "Inter var, sans-serif"

// Axis chrome follows the theme's muted and border tokens rather than Chart.js defaults, which
// are tuned for a white canvas and sink into the dark panel.
const isDark = () => document.documentElement.classList.contains("dark")
const tickColor = () => (isDark() ? "#9ca3af" : "#6b7280")
const gridColor = () => (isDark() ? "#374151" : "#e5e7eb")
const linerColor = () => (isDark() ? "#4b5563" : "#d1d5db")

const STORABLE = ["group", "ntile", "period", "series", "visible"]

const storeChanges = (changes) => {
  for (const [key, val] of Object.entries(changes)) {
    if (STORABLE.includes(key) && val !== undefined) {
      store(`chart-${key}`, val)
    }
  }
}

const formatTime = (seconds) => {
  const date = new Date(parseInt(seconds, 10) * 1000)

  return date.toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    second: "2-digit",
    hour12: true,
  })
}

const estimateCount = function (value) {
  let base
  let mult
  let part
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
    ctx.strokeStyle = linerColor()
    ctx.globalCompositeOperation = "destination-over"
    ctx.stroke()

    ctx.restore()
  },
}

// Bars are hit only when the pointer is inside a segment, so a click on the tall completed bar
// never resolves to a sliver beneath it. Points are tiny, so lines take the nearest point instead.
const elementAt = (chart, event) => {
  const intersect = chart.config.type === "bar"
  const elements = chart.getElementsAtEventForMode(event, "nearest", { intersect }, false)

  return elements.length > 0 ? chart.data.datasets[elements[0].datasetIndex] : null
}

const basicOpts = (hook) => ({
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
  onClick: (event, _elements, chart) => {
    const dataset = elementAt(chart, event)

    if (dataset && dataset.label !== "other") {
      hook.pushEventTo(hook.el, "chart-select", { label: dataset.label })
    }
  },
  onHover: (event, _elements, chart) => {
    const dataset = elementAt(chart, event)

    hook.el.classList.toggle("cursor-pointer", dataset !== null && dataset.label !== "other")
  },
  plugins: {
    legend: {
      display: false,
    },
    verticalLiner: {},
    tooltip: {
      callbacks: {
        title: function (context) {
          return formatTime(context[0].label)
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
})

const xScale = (extra) => ({
  ...extra,
  grid: {
    display: false,
  },
  ticks: {
    color: tickColor(),
    maxRotation: 0,
    minRotation: 0,
    padding: 3,
    callback: function (value, index) {
      if (index % 4 === 0) {
        return formatTime(this.getLabelForValue(value))
      }
    },
  },
})

const yScale = (extra, format) => ({
  ...extra,
  grid: {
    color: gridColor(),
  },
  ticks: {
    color: tickColor(),
    callback: function (value, index, _ticks) {
      if (index % 2 === 0) return format(value)
    },
  },
})

const stackOpts = (hook) => ({
  ...basicOpts(hook),
  scales: {
    x: xScale({ stacked: true }),
    y: yScale({ stacked: true }, estimateCount),
  },
})

const linesOpts = (hook) => ({
  ...basicOpts(hook),
  borderWidth: 2,
  borderJoinStyle: "round",
  radius: 2,
  spanGaps: true,
  scales: {
    x: xScale({}),
    y: yScale({}, estimateNanos),
  },
})

const seriesColor = (type, hex) => {
  if (type === "line" && !isDark()) {
    return LINE_FG[hex] || hex
  } else {
    return hex
  }
}

const JobsChart = {
  mounted() {
    this.chart = null

    this.themeObserver = new MutationObserver(() => this.applyTheme())
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    })

    this.handleEvent("chart-change", (changes) => {
      const { hidden, points, series } = changes

      storeChanges(changes)

      const [type, opts] = /_count/.test(series) ? ["bar", stackOpts(this)] : ["line", linesOpts(this)]
      const plugins = type === "line" ? [liner] : []

      if (this.chart === null) {
        this.chart = new Chart(this.el, { type: type, options: opts, plugins: plugins })
      } else if (this.chart.config.type !== type) {
        this.chart.destroy()
        this.chart = new Chart(this.el, { type: type, options: opts, plugins: plugins })
      }

      const datasets = points.map(({ label, hex, data }) => {
        const color = seriesColor(type, hex)

        return {
          backgroundColor: color,
          barPercentage: 1.0,
          barThickness: "flex",
          borderColor: color,
          data: data.reverse(),
          hex: hex,
          hidden: hidden.includes(label),
          label: label,
        }
      })

      this.chart.data.datasets = datasets
      this.chart.update()
    })
  },

  applyTheme() {
    if (this.chart === null) return

    const type = this.chart.config.type
    const { x, y } = this.chart.options.scales

    x.ticks.color = tickColor()
    y.ticks.color = tickColor()
    y.grid.color = gridColor()

    for (const dataset of this.chart.data.datasets) {
      const color = seriesColor(type, dataset.hex)

      dataset.backgroundColor = color
      dataset.borderColor = color
    }

    this.chart.update()
  },

  destroyed() {
    if (this.themeObserver) {
      this.themeObserver.disconnect()
    }

    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  },
}

export default JobsChart
