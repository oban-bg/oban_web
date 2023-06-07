import "phoenix_html";
import Chart from "chart.js/auto";
import { Socket, LongPoll } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import tippy, { roundArrow } from "tippy.js";
import topbar from "topbar";

const Hooks = {};

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

// Refresher ---

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

// Theme ---

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

// Tooltips ---

Hooks.Tippy = {
  mounted() {
    const content = this.el.getAttribute("data-title");

    tippy(this.el, { arrow: roundArrow, content: content, delay: [250, null] });
  },
};

// Charts ---

Chart.defaults.font.size = 12;
Chart.defaults.font.family = "Inter var";

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

const BASIC_OPTS = {
  animation: false,
  maintainAspectRatio: false,
  normalized: true,
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
}

const STACK_OPTS = {
  ...BASIC_OPTS,
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
  ...BASIC_OPTS,
  scales: {
    x: {
      grid: {
        display: false,
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
      ticks: {
        callback: function (value, index, _ticks) {
          if (index % 2 !== 0) return;

          const milliseconds = value / 1e6;
          const seconds = value / 1e9;
          const minutes = value / 6e10;
          const hours = value / 3.6e12;

          if (hours >= 1) {
            return `${hours.toFixed(1)}h`;
          } else if (minutes >= 1) {
            return `${minutes.toFixed(1)}m`;
          } else if (seconds >= 1) {
            return `${seconds.toFixed(1)}s`;
          } else if (milliseconds >= 1000) {
            return `${milliseconds.toFixed(1)}ms`;
          } else {
            return `${milliseconds.toFixed(0)}ms`;
          }
        },
      },
    },
  },
};

Hooks.Chart = {
  mounted() {
    let chart = null;

    this.handleEvent("chart-change", ({ group, points, series }) => {
      const [type, opts] = /_count/.test(series) ? ["bar", STACK_OPTS] : ["line", LINES_OPTS];

      if (chart === null) {
        chart = new Chart(this.el, { type: type, options: opts });
      } else if (chart.config.type !== type) {
        chart.destroy()
        chart = new Chart(this.el, { type: type, options: opts });
      }

      const datasets = Object.entries(points).map(([label, data], index) => {
        const color = group === "state" ? STATE_PALETTE[label] : OTHER_PALETTE[index];

        return {
          backgroundColor: color,
          barThickness: 9,
          borderColor: color,
          data: data.reverse(),
          label: label,
        };
      });

      chart.data.datasets = datasets;
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
