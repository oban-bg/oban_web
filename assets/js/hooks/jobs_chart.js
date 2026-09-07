import { load, store } from "../lib/settings"
import { LINE_FG } from "../lib/colors"

import {
  BarController,
  BarElement,
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
  LineController,
  LineElement,
  LinearScale,
  PointElement,
  Tooltip,
)

Chart.defaults.font.size = 12
Chart.defaults.font.family = "Inter var, sans-serif"

// This keeps the tooltip beside the column, on whichever side has room, and lets it ride along
// with the pointer vertically.
Tooltip.positioners.beside = function (items, eventPosition) {
  if (!items.length) return false

  const { left, right } = this.chart.chartArea
  const x = items[0].element.getCenterPoint().x

  return {
    x: x,
    y: eventPosition.y,
    xAlign: x < left + (right - left) / 2 ? "left" : "right",
    yAlign: "center",
  }
}

// Axis chrome follows the theme's muted and border tokens rather than Chart.js defaults, which
// are tuned for a white canvas and sink into the dark panel.
const isDark = () => document.documentElement.classList.contains("dark")
const tickColor = () => (isDark() ? "#9ca3af" : "#6b7280")
const gridColor = () => (isDark() ? "#374151" : "#e5e7eb")
const linerColor = () => (isDark() ? "#4b5563" : "#d1d5db")
const ghostColor = () => (isDark() ? "#4b5563" : "#d1d5db")

// Emphasis changes crossfade rather than snap. Numbers never animate: bars sit at absolute times
// and the window itself moves, so there is nothing for a value animation to explain.
const FADE_MS = 200

// The window's right edge trails server time by a period plus a refresh, so a slice has ended
// and been reported before it reaches the edge. Slices arrive beyond the edge and slide in whole,
// which turns a batch of five columns at a 5s refresh into a stream rather than a jump.
const LAG_MARGIN_MS = 250

// While gliding, the edge eases toward its target by this share each frame, so a clock
// correction or a stalled frame becomes a brief change of pace rather than a jump. A gap wider
// than this many periods, as after a hidden tab, snaps instead.
const EASE_SHARE = 0.15
const SNAP_PERIODS = 4

// The clock offset leaks by this much per payload so it can recover if the browser clock is ever
// stepped backwards.
const CLOCK_LEAK_MS = 5

// Frames that would move the plot by less than this are skipped: at long periods the window
// crawls, and redrawing for a hundredth of a pixel is wasted work on a tab left open all day.
const MIN_MOVE_PX = 0.5

// The y-axis holds its ceiling while bars scroll off rather than rescaling on every arrival, and
// only drops once the data has fallen well below it. A moving window is the one thing that
// should move.
const CEILING_SLACK = 0.5

const reducedMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches

const storeSettings = (settings) => {
  for (const [key, value] of Object.entries(settings)) {
    store(`chart-${key}`, value)
  }
}

const formatTime = (seconds) => {
  const date = new Date(Math.round(seconds) * 1000)

  return date.toLocaleTimeString("en-GB", {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
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
  afterInit: (chart) => {
    chart.verticalLiner = {}
  },
  afterEvent: (chart, args) => {
    const { inChartArea } = args
    chart.verticalLiner = { draw: inChartArea }
  },
  beforeTooltipDraw: (chart, args) => {
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

// Colors ---

const parseColor = (color) => {
  if (color.startsWith("#")) {
    return [1, 3, 5].map((offset) => parseInt(color.slice(offset, offset + 2), 16))
  }

  return color
    .slice(color.indexOf("(") + 1, color.indexOf(")"))
    .split(",")
    .map((part) => parseInt(part, 10))
}

const mixColors = (from, to, amount) => {
  const start = parseColor(from)
  const end = parseColor(to)
  const mixed = start.map((value, index) => Math.round(value + (end[index] - value) * amount))

  return `rgb(${mixed[0]}, ${mixed[1]}, ${mixed[2]})`
}

const easeOut = (amount) => 1 - Math.pow(1 - amount, 3)

const seriesColor = (type, hex) => {
  if (type === "line" && !isDark()) {
    return LINE_FG[hex] || hex
  } else {
    return hex
  }
}

// Ghosted series keep their label and hex so the tooltip still names them, but draw in the
// hidden-series gray beneath the emphasised ones. A hovered or focused legend item borrows the
// same treatment for every other series while the pointer rests on it. Targets are recorded here;
// `paint` moves the drawn color toward them, over a short fade when asked to.
const restyle = (chart, highlight, fade) => {
  const type = chart.config.type
  const now = performance.now()

  for (const dataset of chart.data.datasets) {
    const dim = dataset.ghost || (highlight !== null && highlight !== dataset.label)
    const target = dim ? ghostColor() : seriesColor(type, dataset.hex)

    if (type === "line") {
      dataset.borderWidth = dim ? 1 : 2
      dataset.order = dim ? 1 : 0
    }

    if (target === dataset.target) continue

    if (fade && dataset.color) {
      dataset.fadeFrom = dataset.color
      dataset.fadeStart = now
    } else {
      dataset.fadeFrom = null
    }

    dataset.target = target
  }
}

const paint = (chart, now) => {
  let fading = false

  for (const dataset of chart.data.datasets) {
    let color = dataset.target

    if (dataset.fadeFrom) {
      const amount = (now - dataset.fadeStart) / FADE_MS

      if (amount < 1) {
        color = mixColors(dataset.fadeFrom, dataset.target, easeOut(amount))
        fading = true
      } else {
        dataset.fadeFrom = null
      }
    }

    dataset.color = color
    dataset.backgroundColor = color
    dataset.borderColor = color
  }

  return fading
}

const legendLabel = (target) => {
  const item = target instanceof Element ? target.closest('[id^="legend-"]') : null

  return item ? item.getAttribute("phx-value-label") : null
}

// Options ---

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
      position: "beside",
      caretPadding: 8,
      boxHeight: 8,
      boxWidth: 8,
      boxPadding: 4,
      usePointStyle: true,
      // Empty slices have no row, so a quiet second reads as a short list rather than a column
      // of zeros that can outgrow the plot.
      filter: (item) => item.raw.y !== null,
      callbacks: {
        title: function (context) {
          return formatTime(context[0].raw.t)
        },

        label: function (context) {
          const type = context.chart.config.type
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

// Time runs along a linear axis in unix seconds so the window can slide between refreshes. Ticks
// are generated by hand at clock multiples of a label interval so they travel with the data
// instead of hanging off the window's moving edge. The interval is the smallest clock-friendly
// step that leaves each label room to breathe at the axis's current width.
const LABEL_INTERVALS = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600, 7200]
const LABEL_ROOM = 96

// Chart.js widens the plot's side padding to fit whichever label sits nearest an edge, and that
// padding changes as the edge label slides, which moves every bar. Labels are only kept once
// they fit inside the plot with room to spare, so the padding never has to change.
const LABEL_EDGE = 40

const clockTicks = (axis) => {
  const width = axis.maxWidth || axis.chart.width
  const span = axis.max - axis.min
  const slots = Math.max(1, Math.floor(width / LABEL_ROOM))
  const wanted = span / slots
  const interval = LABEL_INTERVALS.find((candidate) => candidate >= wanted) ?? LABEL_INTERVALS.at(-1)
  const edge = (LABEL_EDGE / width) * span
  const ticks = []

  for (let value = Math.ceil(axis.min / interval) * interval; value <= axis.max; value += interval) {
    if (value >= axis.min + edge && value <= axis.max - edge) ticks.push({ value })
  }

  axis.ticks = ticks
}

const xScale = (extra) => ({
  ...extra,
  type: "linear",
  offset: false,
  bounds: "data",
  afterBuildTicks: clockTicks,
  grid: {
    display: false,
  },
  ticks: {
    color: tickColor(),
    maxRotation: 0,
    minRotation: 0,
    padding: 3,
    callback: (value) => formatTime(value),
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
  borderJoinStyle: "round",
  radius: 0,
  hitRadius: 8,
  hoverRadius: 3,
  spanGaps: true,
  scales: {
    x: xScale({}),
    y: yScale({}, estimateNanos),
  },
})

// Hook ---

const JobsChart = {
  mounted() {
    this.chart = null
    this.ceiling = 0
    this.ceilingType = null
    this.dirty = false
    this.drawnEdge = null
    this.edge = null
    this.frame = null
    this.highlight = null
    this.history = new Map()
    this.historyKey = null
    this.offset = null
    this.refresh = load("refresh") ?? 1
    this.span = 100
    this.step = 1
    this.visible = true

    this.themeObserver = new MutationObserver(() => this.applyTheme())
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    })

    // The legend is a sibling of the canvas that re-renders on its own, so hover and focus are
    // delegated from the shared body rather than bound to legend items directly.
    this.body = this.el.closest("#chart-body")
    this.handleHighlight = (event) => this.setHighlight(legendLabel(event.target))
    this.handleUnhighlight = () => this.setHighlight(null)

    if (this.body) {
      this.body.addEventListener("mouseover", this.handleHighlight)
      this.body.addEventListener("focusin", this.handleHighlight)
      this.body.addEventListener("mouseleave", this.handleUnhighlight)
      this.body.addEventListener("focusout", this.handleUnhighlight)
    }

    this.handleVisibility = () => this.schedule()
    document.addEventListener("visibilitychange", this.handleVisibility)

    this.motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.handleMotion = () => this.schedule()
    this.motionQuery.addEventListener("change", this.handleMotion)

    this.handleEvent("update-refresh", ({ refresh }) => {
      this.refresh = refresh
      this.schedule()
    })

    this.handleEvent("chart-change", (changes) => {
      const { hidden, key, now, points, series, settings, step } = changes

      if (settings) {
        storeSettings(settings)
        this.visible = settings.visible
      }

      this.step = step
      this.span = points[0]?.data.length ?? this.span
      this.syncClock(now)

      if (key !== this.historyKey) {
        this.history = new Map()
        this.historyKey = key
      }

      const type = /_count/.test(series) ? "bar" : "line"

      if (this.chart !== null && this.chart.config.type !== type) {
        this.chart.destroy()
        this.chart = null
      }

      if (this.chart === null) {
        const opts = type === "bar" ? stackOpts(this) : linesOpts(this)
        const plugins = type === "line" ? [liner] : []

        this.chart = new Chart(this.el, { type: type, options: opts, plugins: plugins })
      }

      this.mergePoints(points, hidden)
      restyle(this.chart, this.highlight, true)
      this.holdCeiling(type)
      this.dirty = true
      this.render()
    })
  },

  // The server sends the newest slices only, but the window trails server time, so a few slices
  // older than the server's cut are kept from earlier payloads to let the oldest bar scroll off
  // the edge instead of vanishing short of it. Dataset objects are reused by label so Chart.js
  // keeps its element caches and a colour fade in progress survives the arrival.
  mergePoints(points, hidden) {
    const step = this.step
    const oldest = this.serverNow() - this.lag() - (this.span + 1) * step
    const labels = new Set(points.map((series) => series.label))
    const existing = new Map(this.chart.data.datasets.map((dataset) => [dataset.label, dataset]))

    for (const label of this.history.keys()) {
      if (!labels.has(label)) this.history.delete(label)
    }

    this.chart.data.datasets = points.map(({ label, hex, ghost, data }) => {
      const slices = new Map()

      for (const [time, value] of this.history.get(label) ?? []) {
        if (time >= oldest) slices.set(time, value)
      }

      for (const point of data) {
        slices.set(point.x, point.y)
      }

      this.history.set(label, slices)

      const dataset = existing.get(label) ?? {
        barPercentage: 1.0,
        barThickness: "flex",
        label: label,
      }

      // Slices cover the period ending at their timestamp, so each bar is centred half a step
      // back from the time it reports.
      dataset.data = [...slices.entries()]
        .sort((left, right) => left[0] - right[0])
        .map(([time, value]) => ({ x: time - step / 2, y: value, t: time }))
      dataset.ghost = ghost
      dataset.hex = hex
      dataset.hidden = hidden.includes(label)

      return dataset
    })
  },

  holdCeiling(type) {
    const datasets = this.chart.data.datasets.filter((dataset) => !dataset.hidden)
    const totals = new Map()

    for (const dataset of datasets) {
      for (const point of dataset.data) {
        if (point.y === null) continue

        const current = totals.get(point.x) ?? 0

        totals.set(point.x, type === "bar" ? current + point.y : Math.max(current, point.y))
      }
    }

    const peak = Math.max(0, ...totals.values())
    const stale =
      this.ceilingType !== type || peak > this.ceiling || peak < this.ceiling * CEILING_SLACK

    if (stale) {
      this.ceiling = peak
      this.ceilingType = type
    }

    this.chart.options.scales.y.suggestedMax = this.ceiling
  },

  // Server time is estimated from each payload's clock. Every sample arrives late by its own
  // transport and render delay, so the largest sample seen is the closest to the true offset,
  // and the first one, taken through a page load, is superseded by the next payload.
  syncClock(serverMillis) {
    const sample = serverMillis - Date.now()

    this.offset = this.offset === null ? sample : Math.max(this.offset - CLOCK_LEAK_MS, sample)
  },

  serverNow() {
    return (Date.now() + (this.offset ?? 0)) / 1000
  },

  gliding() {
    return (
      this.chart !== null &&
      this.visible &&
      this.refresh > 0 &&
      document.visibilityState === "visible" &&
      !reducedMotion()
    )
  },

  lag() {
    return this.step + Math.max(this.refresh, 0) + LAG_MARGIN_MS / 1000
  },

  // Place the window so its right edge trails server time by a period and a refresh interval,
  // then report whether the plot would visibly move from where it was last drawn.
  placeWindow() {
    const width = this.span * this.step
    const target = this.serverNow() - this.lag()
    const gap = this.edge === null ? Infinity : Math.abs(target - this.edge)

    if (!this.gliding() || gap > this.step * SNAP_PERIODS) {
      this.edge = target
    } else {
      this.edge += (target - this.edge) * EASE_SHARE
    }

    this.chart.options.scales.x.max = this.edge
    this.chart.options.scales.x.min = this.edge - width

    const pixels = (this.chart.chartArea?.width ?? 0) / width

    return this.drawnEdge === null || Math.abs(this.edge - this.drawnEdge) * pixels >= MIN_MOVE_PX
  },

  render() {
    if (this.chart === null) return

    const moved = this.placeWindow()
    const fading = paint(this.chart, performance.now())

    // Animations are off, so a default-mode update assigns directly. The "none" mode would too,
    // but it also skips refreshing the options Chart.js shares across a reused dataset's bars,
    // which would leave recoloured bars drawn in their old paint.
    if (moved || fading || this.dirty) {
      this.chart.update()
      this.drawnEdge = this.edge
      this.dirty = false
    }

    if (fading || this.gliding()) {
      this.schedule()
    }
  },

  schedule() {
    if (this.frame !== null || this.chart === null) return

    this.frame = window.requestAnimationFrame(() => {
      this.frame = null
      this.render()
    })
  },

  setHighlight(label) {
    if (label === this.highlight) return

    this.highlight = label

    if (this.chart === null) return

    restyle(this.chart, this.highlight, true)
    this.dirty = true
    this.schedule()
  },

  applyTheme() {
    if (this.chart === null) return

    const { x, y } = this.chart.options.scales

    x.ticks.color = tickColor()
    y.ticks.color = tickColor()
    y.grid.color = gridColor()

    restyle(this.chart, this.highlight, false)
    this.dirty = true
    this.schedule()
  },

  destroyed() {
    if (this.frame !== null) {
      window.cancelAnimationFrame(this.frame)
      this.frame = null
    }

    if (this.themeObserver) {
      this.themeObserver.disconnect()
    }

    if (this.motionQuery) {
      this.motionQuery.removeEventListener("change", this.handleMotion)
    }

    document.removeEventListener("visibilitychange", this.handleVisibility)

    if (this.body) {
      this.body.removeEventListener("mouseover", this.handleHighlight)
      this.body.removeEventListener("focusin", this.handleHighlight)
      this.body.removeEventListener("mouseleave", this.handleUnhighlight)
      this.body.removeEventListener("focusout", this.handleUnhighlight)
    }

    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  },
}

export default JobsChart
