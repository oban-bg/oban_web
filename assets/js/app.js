import css from "../css/app.css"

import "phoenix_html"
import {Socket, LongPoll} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
const transport = document.querySelector("meta[name='live-transport']").getAttribute("content");

const liveSocket = new LiveSocket("/live", Socket, {
  transport: transport === "longpoll" ? LongPoll : WebSocket,
  params: {_csrf_token: csrfToken}
});

liveSocket.connect();
