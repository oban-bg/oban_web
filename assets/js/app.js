// Phoenix assets are imported from dependencies
import topbar from "topbar";

import { loadAll } from "./lib/settings";

import Completer from "./hooks/completer";
import CronChart from "./hooks/cron_chart";
import JobsChart from "./hooks/jobs_chart";
import HistoryBack from "./hooks/history_back";
import Instantiator from "./hooks/instantiator";
import Refresher from "./hooks/refresher";
import Relativize from "./hooks/relativize";
import Shortcuts from "./hooks/shortcuts";
import SidebarResizer from "./hooks/sidebar_resizer";
import Sparkline from "./hooks/sparkline";
import Themer from "./hooks/themer";
import TimelineConnectors from "./hooks/timeline_connectors";
import Tippy from "./hooks/tippy";

const hooks = {
  Completer,
  CronChart,
  JobsChart,
  HistoryBack,
  Instantiator,
  Refresher,
  Relativize,
  Shortcuts,
  SidebarResizer,
  Sparkline,
  Themer,
  TimelineConnectors,
  Tippy,
};

// Topbar ---

let topBarScheduled = undefined;

topbar.config({
  barColors: { 0: "#0284c7" },
  shadowColor: "rgba(0, 0, 0, .3)",
});

window.addEventListener("phx:page-loading-start", (info) => {
  if (!topBarScheduled) {
    topBarScheduled = setTimeout(() => topbar.show(), 500);
  }
});

window.addEventListener("phx:page-loading-stop", (info) => {
  clearTimeout(topBarScheduled);
  topBarScheduled = undefined;
  topbar.hide();
});

// Mounting ---

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
const liveTran = document.querySelector("meta[name='live-transport']").getAttribute("content");
const livePath = document.querySelector("meta[name='live-path']").getAttribute("content");

const liveSocket = new LiveView.LiveSocket(livePath, Phoenix.Socket, {
  transport: liveTran === "longpoll" ? Phoenix.LongPoll : WebSocket,
  params: { _csrf_token: csrfToken, init_state: loadAll() },
  hooks: hooks,
});

liveSocket.connect();
