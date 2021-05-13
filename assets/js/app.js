import css from "../css/app.css"
import NProgress from "nprogress"

import "phoenix_html"
import {Socket, LongPoll} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
const transport = document.querySelector("meta[name='live-transport']").getAttribute("content");

const liveSocket = new LiveSocket("/live", Socket, {
  transport: transport === "longpoll" ? LongPoll : WebSocket,
  params: {_csrf_token: csrfToken}
});

liveSocket.connect();
