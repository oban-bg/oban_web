import {Socket} from "../../deps/phoenix/priv/static/phoenix"
import {LiveSocket} from "../../deps/phoenix_live_view/priv/static/phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}});

liveSocket.connect()
