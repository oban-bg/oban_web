import "phoenix_html"
import {Socket, LongPoll} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import tippy, {roundArrow} from "tippy.js"
import topbar from "topbar"

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

let Hooks = {}

Hooks.Refresher = {
  mounted() {
    const targ = "#refresh-selector"
    const elem = this

    document.addEventListener("visibilitychange", _event => {
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
      option.addEventListener("click", _event => {
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

    this.el.addEventListener("click", _event => {
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

    tippy(this.el, { arrow: roundArrow, content: content, delay: [500, null] });
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
const liveTran = document.querySelector("meta[name='live-transport']").getAttribute("content");
const livePath = document.querySelector("meta[name='live-path']").getAttribute("content");

const liveSocket = new LiveSocket(livePath, Socket, {
  transport: liveTran === "longpoll" ? LongPoll : WebSocket,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
});

liveSocket.connect();
