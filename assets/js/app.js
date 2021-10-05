import "phoenix_html"
import {Socket, LongPoll} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "topbar"

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"});
window.addEventListener("phx:page-loading-start", info => topbar.show());
window.addEventListener("phx:page-loading-stop", info => topbar.hide());

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
const transport = document.querySelector("meta[name='live-transport']").getAttribute("content");
const socketPath = document.querySelector("meta[name='live-path']").getAttribute("content");

const liveSocket = new LiveSocket("/live", Socket, {
  transport: transport === "longpoll" ? LongPoll : WebSocket,
  params: {_csrf_token: csrfToken}
});

liveSocket.connect();
