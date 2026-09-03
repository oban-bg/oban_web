import {
  BarController,
  BarElement,
  CategoryScale,
  Chart,
  LinearScale,
  Tooltip,
} from "chart.js";

import { CYAN, GRAY } from "../lib/colors";

Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip);

// Axis chrome follows the theme's muted and border tokens rather than Chart.js defaults, which
// are tuned for a white canvas and sink into the dark well.
const isDark = () => document.documentElement.classList.contains("dark");
const tickColor = () => (isDark() ? "#9ca3af" : "#6b7280");
const gridColor = () => (isDark() ? "#374151" : "#e5e7eb");

const formatTime = (timestamp) => {
  const date = new Date(timestamp);
  return date.toLocaleString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });
};

const QueueDetailChart = {
  mounted() {
    const canvas = document.createElement("canvas");
    this.el.appendChild(canvas);

    this.chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: [],
        datasets: [
          {
            data: [],
            backgroundColor: CYAN,
            borderRadius: 2,
            barPercentage: 0.9,
            categoryPercentage: 0.9,
          },
        ],
      },
      options: {
        animation: false,
        maintainAspectRatio: false,
        responsive: true,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              title: (context) => formatTime(parseInt(context[0].label, 10)),
              label: (context) => {
                const count = context.raw;
                const label = count === 1 ? "job" : "jobs";
                return `${count} ${label}`;
              },
            },
          },
        },
        scales: {
          x: {
            display: true,
            grid: { display: false },
            ticks: {
              color: tickColor(),
              maxRotation: 0,
              autoSkip: true,
              maxTicksLimit: 6,
              // Slots are five seconds apart but labels are whole minutes, so only the slot that
              // starts a minute keeps its label. Otherwise adjacent ticks can both read "4:40 PM".
              callback: function (value) {
                const timestamp = parseInt(this.getLabelForValue(value), 10);

                return new Date(timestamp).getSeconds() === 0
                  ? formatTime(timestamp)
                  : null;
              },
            },
          },
          y: {
            display: true,
            beginAtZero: true,
            grid: { color: gridColor() },
            ticks: {
              color: tickColor(),
              stepSize: 1,
              callback: (value) => (Number.isInteger(value) ? value : null),
            },
          },
        },
      },
    });

    this.themeObserver = new MutationObserver(() => this.applyTheme());
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    });

    this.handleEvent("queue-history", ({ history }) => {
      this.data = history;

      this.chart.data.labels = history.map((point) => point.timestamp);
      this.chart.data.datasets[0].data = history.map((point) => point.count);
      this.chart.update();
    });
  },

  applyTheme() {
    const { x, y } = this.chart.options.scales;

    x.ticks.color = tickColor();
    y.ticks.color = tickColor();
    y.grid.color = gridColor();

    this.chart.update();
  },

  destroyed() {
    if (this.themeObserver) {
      this.themeObserver.disconnect();
    }

    if (this.chart) {
      this.chart.destroy();
    }
  },
};

export default QueueDetailChart;
