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

// fill-cyan-400
// fill-violet-400
// fill-yellow-400
// fill-green-400
// fill-orange-400
// fill-teal-400
// fill-pink-300

const STACK_OPTS = {
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
      stacked: true,
      grid: {
        display: false
      },
    },
    y: {
      stacked: true,
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
      display: false,
    },
  },
}

Hooks.Chart = {
  mounted() {
    let date = new Date();

    const data = {
      labels: [...Array(100).keys()].map((x) => {
        date = new Date(date.getTime() - x * 1000);
        return date.toLocaleTimeString("en-US", {
          hour12: false,
          timeStyle: "short",
        });
      }),
      datasets: [
        {
          label: "completed",
          data: [],
          barThickness: 9,
          borderColor: "#22d3ee",
          backgroundColor: "#22d3ee",
        },
        {
          label: "cancelled",
          data: [],
          barThickness: 9,
          borderColor: "#a78bfa",
          backgroundColor: "#a78bfa",
        },
        {
          label: "discarded",
          data: [],
          barThickness: 9,
          borderColor: "#fb7185",
          backgroundColor: "#fb7185",
        },
        {
          label: "retryable",
          data: [],
          barThickness: 9,
          borderColor: "#facc15",
          backgroundColor: "#facc15",
        },
        {
          label: "scheduled",
          data: [],
          barThickness: 9,
          borderColor: "#4ade80",
          backgroundColor: "#4ade80",
        },
      ],
    };

    const chart = new Chart(this.el, { type: "bar", options: STACK_OPTS, data: data });

    this.handleEvent("chart-update", ({ points }) => {
      chart.data.datasets.forEach((dataset) => {
        const data = [points[dataset.label]].flat();

        dataset.data.splice(0, data.length);
        dataset.data.push(...data);
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
