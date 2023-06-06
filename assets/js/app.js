import "phoenix_html";
import Chart from "chart.js/auto";
import { Socket, LongPoll } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import tippy, { roundArrow } from "tippy.js";
import topbar from "topbar";

Chart.defaults.font.size = 12;
Chart.defaults.font.family = "Inter var";

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

// Hooks ---

const Hooks = {};

Hooks.Refresher = {
  mounted() {
    const targ = "#refresh-selector";
    const elem = this;

    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "visible") {
        elem.pushEventTo(targ, "resume-refresh", {});
      } else {
        elem.pushEventTo(targ, "pause-refresh", {});
      }
    });

    if ("refresh" in localStorage) {
      elem.pushEventTo(targ, "select-refresh", { value: localStorage.refresh });
    }

    this.el.querySelectorAll("[role='option']").forEach((option) => {
      option.addEventListener("click", () => {
        localStorage.refresh = option.getAttribute("value");
      });
    });
  },
};

Hooks.RestoreTheme = {
  mounted() {
    this.pushEventTo("#theme-selector", "restore", {
      theme: localStorage.theme,
    });
  },
};

Hooks.ChangeTheme = {
  applyTheme() {
    const wantsDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    const noPreference = !("theme" in localStorage);

    if (
      localStorage.theme === "dark" ||
      (localStorage.theme === "system" && wantsDark) ||
      (noPreference && wantsDark)
    ) {
      document.documentElement.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
    }
  },

  mounted() {
    const elem = this;

    this.el.addEventListener("click", () => {
      const theme = this.el.getAttribute("value");

      localStorage.theme = theme;

      this.applyTheme();

      elem.pushEventTo("#theme-selector", "restore", { theme: theme });
    });
  },
};

Hooks.Tippy = {
  mounted() {
    const content = this.el.getAttribute("data-title");

    tippy(this.el, { arrow: roundArrow, content: content, delay: [250, null] });
  },
};

const STACK_OPTS = {
  animation: false,
  maintainAspectRatio: false,
  interaction: {
    mode: "index",
  },
  layout: {
    padding: {
      bottom: 4,
    },
  },
  plugins: {
    legend: {
      display: false,
    },
    tooltip: {
      callbacks: {
        title: function (context) {
          const date = new Date(parseInt(context[0].label) * 1000);

          return date.toLocaleTimeString("en-US", { hour12: false, timeStyle: "long" });
        },
      },
    },
  },
  scales: {
    x: {
      stacked: true,
      grid: {
        display: false,
        drawTicks: true,
      },
      ticks: {
        maxRotation: 0,
        minRotation: 0,
        padding: 3,
        callback: function (value, index) {
          if (index % 4 === 0) {
            const date = new Date(parseInt(this.getLabelForValue(value)) * 1000);

            return date.toLocaleTimeString("en-US", { hour12: false, timeStyle: "medium" });
          }
        },
      },
    },
    y: {
      stacked: true,
      ticks: {
        callback: function (value, index, _ticks) {
          if (index % 2 !== 0) return;

          if (value < 1000) {
            return value;
          } else {
            const log = Math.max(Math.floor(Math.log10(value)), 5);
            const mult = Math.pow(10, log - 2);
            const base = Math.floor(value / mult);
            const part = Math.round((value % mult) / Math.pow(10, log - 3));

            if (part === 0) {
              return `${base}k`;
            } else if (part === 10) {
              return `${base + 1}k`;
            } else {
              return `${base}.${part}k`;
            }
          }
        },
      },
    },
  },
};

const LINES_OPTS = {
  maintainAspectRatio: false,
  interaction: {
    mode: "index",
  },
  plugins: {
    legend: {
      display: false,
    },
  },
  scales: {
    x: {
      grid: {
        display: false,
      },
      ticks: {
        maxRotation: 0,
        minRotation: 0,
      },
    },
  },
};

const CYAN = "#22d3ee"; // cyan-400
const EMERALD = "#34d399"; // emerald-400
const ORANGE = "#fb923c"; // orange-400
const ROSE = "#fb7185"; // rose-400
const TEAL = "#2dd4bf"; // teal-500
const VIOLET = "#a78bfa"; // violet-400
const YELLOW = "#facc15"; // yellow-400

const OTHER_PALETTE = [
  CYAN,
  VIOLET,
  YELLOW,
  EMERALD,
  ORANGE,
  TEAL,
  ROSE,
]

const STATE_PALETTE = {
  available: TEAL,
  completed: CYAN,
  cancelled: VIOLET,
  discarded: ROSE,
  executing: ORANGE,
  retryable: YELLOW,
  scheduled: EMERALD,
};

Hooks.Chart = {
  initDataset(label, color, data = []) {
    return {
      backgroundColor: color,
      barThickness: 9,
      borderColor: color,
      data: data,
      label: label,
    };
  },

  mounted() {
    const chart = new Chart(this.el, { type: "bar", options: STACK_OPTS, data: {}});

    this.handleEvent("chart-change", ({ group, points }) => {
      const datasets = Object.entries(points).map(([label, data], index) => {
        const color = group === "state" ? STATE_PALETTE[label] : OTHER_PALETTE[index];

        return this.initDataset(label, color, data);
      });

      chart.data.datasets = datasets;
      chart.update();
    });

    this.handleEvent("chart-update", ({ points }) => {
      // TODO: Append missing datasets (needed for workers or nodes)
      // TODO: Replace previous data point when x overlaps
      const [sample] = Object.values(points);
      const [{ x }] = sample;

      chart.data.datasets.forEach((dataset) => {
        const data = points[dataset.label];

        if (data !== undefined) {
          dataset.data.splice(0, data.length);
          dataset.data.push(...data);
        } else {
          dataset.data.splice(0, sample.length);
          dataset.data.push({ x: x, y: null });
        }
      });

      chart.update();
    });
  },
};

// Mounting ---

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

const liveTran = document.querySelector("meta[name='live-transport']").getAttribute("content");

const livePath = document.querySelector("meta[name='live-path']").getAttribute("content");

const liveSocket = new LiveSocket(livePath, Socket, {
  transport: liveTran === "longpoll" ? LongPoll : WebSocket,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

liveSocket.connect();
