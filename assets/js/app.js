import css from "../css/app.css"

import "../../deps/phoenix_html/priv/static/phoenix_html"
import {Socket, LongPoll} from "../../deps/phoenix/priv/static/phoenix"
import {LiveSocket} from "../../deps/phoenix_live_view/priv/static/phoenix_live_view"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
const transport = document.querySelector("meta[name='live-transport']").getAttribute("content");

const liveSocket = new LiveSocket("/live", Socket, {
  transport: transport === "longpoll" ? LongPoll : WebSocket,
  params: {_csrf_token: csrfToken}
});

liveSocket.connect();
