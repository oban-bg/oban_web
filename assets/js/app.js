import "phoenix_html"
import {Socket, LongPoll} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import tippy, {roundArrow} from "tippy.js"
import topbar from "topbar"

topbar.config({barColors: {0: "#0284c7"}, shadowColor: "rgba(0, 0, 0, .3)"});
window.addEventListener("phx:page-loading-start", info => topbar.show());
window.addEventListener("phx:page-loading-stop", info => topbar.hide());

let Hooks = {}

Hooks.ToggleRefresh = {
  mounted() {
    let elem = this;

    document.addEventListener("visibilitychange", _event => {
      if (document.visibilityState === "visible") {
        elem.pushEventTo("#refresh", "resume-refresh", {})
      } else {
        elem.pushEventTo("#refresh", "pause-refresh", {})
      }
    });
  }
}

Hooks.ToggleDarkMode = {
  setMode() {
    if (localStorage.theme === "dark" || (!("theme" in localStorage) && window.matchMedia("(prefers-color-scheme: dark)").matches)) {
      document.documentElement.classList.add("dark")
    } else {
      document.documentElement.classList.remove("dark")
    }
  },

  mounted() {
    this.el.addEventListener("click", _event => {
      localStorage.theme = localStorage.theme === "dark" ? "light" : "dark";

      this.setMode();
    })

    const content = this.el.getAttribute("data-title");

    tippy(this.el, { arrow: roundArrow, content: content, delay: [500, null] });
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
