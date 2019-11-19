import {Socket} from "../../deps/phoenix/priv/static/phoenix"
import {LiveSocket} from "../../deps/phoenix_live_view/priv/static/phoenix_live_view"

let liveSocket = new LiveSocket("/live", Socket)
liveSocket.connect()
