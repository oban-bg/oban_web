import "phoenix_html"
import {Socket, LongPoll} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import tippy, {roundArrow} from "tippy.js"
import topbar from "topbar"

// Topbar ---

let topBarScheduled = undefined

topbar.config({barColors: {0: "#0284c7"}, shadowColor: "rgba(0, 0, 0, .3)"})

window.addEventListener("phx:page-loading-start", (info) => {
  if(!topBarScheduled) {
    topBarScheduled = setTimeout(() => topbar.show(), 500)
  }
})

window.addEventListener("phx:page-loading-stop", (info) => {
  clearTimeout(topBarScheduled)
  topBarScheduled = undefined
  topbar.hide()
})

// Hooks ---

let Hooks = {}

Hooks.Refresher = {
  mounted() {
    const targ = "#refresh-selector"
    const elem = this

    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "visible") {
        elem.pushEventTo(targ, "resume-refresh", {})
      } else {
        elem.pushEventTo(targ, "pause-refresh", {})
      }
    })

    if ("refresh" in localStorage) {
      elem.pushEventTo(targ, "select-refresh", {value: localStorage.refresh})
    }

    this.el.querySelectorAll("[role='option']").forEach(option => {
      option.addEventListener("click", () => {
        localStorage.refresh = option.getAttribute("value")
      })
    });
  }
}

Hooks.RestoreTheme = {
  mounted() {
    this.pushEventTo("#theme-selector", "restore", {theme: localStorage.theme})
  }
}

Hooks.ChangeTheme = {
  applyTheme() {
    const wantsDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    const noPreference = !("theme" in localStorage)

    if ((localStorage.theme === "dark") || (localStorage.theme === "system" && wantsDark) || (noPreference && wantsDark)) {
      document.documentElement.classList.add("dark")
    } else {
      document.documentElement.classList.remove("dark")
    }
  },

  mounted() {
    let elem = this;

    this.el.addEventListener("click", () => {
      const theme = this.el.getAttribute("value")

      localStorage.theme = theme

      this.applyTheme()

      elem.pushEventTo("#theme-selector", "restore", {theme: theme})
    })
  }
}

Hooks.Tippy = {
  mounted() {
    const content = this.el.getAttribute("data-title");

    tippy(this.el, { arrow: roundArrow, content: content, delay: [250, null] });
  }
}

Hooks.Chart = {
  mounted() {
    const toolY = 192
    const toolPad = 16
    const toolXOffset = 28
    const toolBleed = 10
    const textHeight = 16
    const textPadding = 2
    const baseLabelX = 12
    const baseLabelY = 42
    const baseToolWidth = 120
    const timeOpts = { hour12: false, timeStyle: "long" }

    const datacol = this.el.querySelector("#chart-d")
    const wrapper = this.el.querySelector("#chart-tooltip-wrapper")
    const tooltip = this.el.querySelector("[rel='chart-tooltip']").cloneNode(true)
    const toollab = this.el.querySelector("[rel='chart-tooltip-label']")
    const tiparrw = tooltip.querySelector("[rel='arrw']")
    const tiptext = tooltip.querySelector("[rel='date']")
    const tiprect = tooltip.querySelector("[rel='rect']")
    const tiplabs = tooltip.querySelector("[rel='labs']")

    tooltip.setAttribute("transform", `translate(-100000,${toolY})`)
    wrapper.appendChild(tooltip)

    datacol.addEventListener("mouseleave", () => {
      tooltip.setAttribute("transform", `translate(-100000,${toolY})`)
    })

    datacol.addEventListener("mouseover", event => {
      const parent = event.target.parentElement

      // Replace timestamp
      const tstamp = parent.getAttribute("data-tstamp") * 1000
      const tevent = new Date(tstamp)

      tiptext.childNodes[0].nodeValue = tevent.toLocaleTimeString("en-US", timeOpts)

      // Replace labels
      const trects = [...parent.querySelectorAll("rect[data-value]")]
      let y = baseLabelY

      tiplabs.replaceChildren()

      trects.reverse().forEach(el => {
        const label = el.getAttribute("data-label")
        const value = el.getAttribute("data-value")
        const group = toollab.cloneNode(true)
        const gcirc = group.querySelector("circle")
        const gtext = group.querySelector("text").childNodes[0]

        gtext.nodeValue = `${label} ${value}`
        gcirc.setAttribute("class", el.getAttribute("class"))
        group.setAttribute("transform", `translate(${baseLabelX}, ${y})`)

        tiplabs.appendChild(group)

        y += textHeight
      })

      // Resize tooltip elements
      const labsWidth = 2 * Math.round(tiplabs.getBBox().width / 2)
      const toolWidth = Math.max(baseToolWidth, labsWidth + toolPad)
      const bleed = window.visualViewport.width - event.clientX - toolWidth / 2 - toolBleed

      tiparrw.setAttribute("transform", `translate(${toolWidth / 2 - 8})`)
      tiprect.setAttribute("height", y - textHeight + textPadding);
      tiprect.setAttribute("width", toolWidth)

      if (bleed < 0) {
        const translate = `translate(${bleed})`

        tiprect.setAttribute("transform", translate)
        tiptext.setAttribute("transform", translate)
        tiplabs.setAttribute("transform", translate)
      } else {
        tiprect.removeAttribute("transform")
        tiptext.removeAttribute("transform")
        tiplabs.removeAttribute("transform")
      }

      // Make tooltip visible
      const offset = parent.getAttribute("data-offset") - (toolWidth / 2) + toolXOffset

      tooltip.setAttribute("transform", `translate(${offset},${toolY})`)
    })
  }
}

// Mounting ---

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
const liveTran = document.querySelector("meta[name='live-transport']").getAttribute("content");
const livePath = document.querySelector("meta[name='live-path']").getAttribute("content");

const liveSocket = new LiveSocket(livePath, Socket, {
  transport: liveTran === "longpoll" ? LongPoll : WebSocket,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
});

liveSocket.connect();
