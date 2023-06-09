import "phoenix_html"
import { Socket, LongPoll } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "topbar"

import Charter from "./hooks/chart"
import Refresher from "./hooks/refresher"
import { ChangeTheme, RestoreTheme } from "./hooks/theme"
import Tippy from "./hooks/tippy"

const hooks = { ChangeTheme, Charter, Refresher, RestoreTheme, Tippy }

// Topbar ---

let topBarScheduled = undefined

topbar.config({
  barColors: { 0: "#0284c7" },
  shadowColor: "rgba(0, 0, 0, .3)",
})

window.addEventListener("phx:page-loading-start", (info) => {
  if (!topBarScheduled) {
    topBarScheduled = setTimeout(() => topbar.show(), 500)
  }
})

window.addEventListener("phx:page-loading-stop", (info) => {
  clearTimeout(topBarScheduled)
  topBarScheduled = undefined
  topbar.hide()
})

// Mounting ---

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const liveTran = document.querySelector("meta[name='live-transport']").getAttribute("content")

const livePath = document.querySelector("meta[name='live-path']").getAttribute("content")

const liveSocket = new LiveSocket(livePath, Socket, {
  transport: liveTran === "longpoll" ? LongPoll : WebSocket,
  params: { _csrf_token: csrfToken },
  hooks: hooks,
  metadata: {
    keyup: (event, el) => {
      return {
        key: event.key,
        ctrlKey: event.ctrlKey,
        metaKey: event.metaKey,
        shiftKey: event.shiftKey
      }
    }
  }
})

liveSocket.connect()
