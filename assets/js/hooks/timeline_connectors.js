const TimelineConnectors = {
  mounted() {
    this.drawConnectors();
    this.resizeObserver = new ResizeObserver(() => this.drawConnectors());
    this.resizeObserver.observe(this.el);
  },

  updated() {
    this.drawConnectors();
  },

  destroyed() {
    this.resizeObserver.disconnect();
  },

  drawConnectors() {
    const svg = this.el.querySelector("#timeline-connectors");
    const container = this.el.querySelector("#timeline-boxes");
    const containerRect = container.getBoundingClientRect();

    const boxEdge = (id, side) => {
      const rect = this.el.querySelector(`#timeline-${id}`).getBoundingClientRect();
      let x, y;
      switch (side) {
        case "right":
          x = rect.right - containerRect.left;
          y = rect.top - containerRect.top + rect.height / 2;
          break;
        case "left":
          x = rect.left - containerRect.left;
          y = rect.top - containerRect.top + rect.height / 2;
          break;
        case "top":
          x = rect.left - containerRect.left + rect.width / 2;
          y = rect.top - containerRect.top;
          break;
        case "bottom":
          x = rect.left - containerRect.left + rect.width / 2;
          y = rect.bottom - containerRect.top;
          break;
      }
      return { x, y };
    };

    const suspended = boxEdge("suspended", "right");
    const suspendedB = boxEdge("suspended", "bottom");
    const scheduledT = boxEdge("scheduled", "top");
    const scheduled = boxEdge("scheduled", "right");
    const retryable = boxEdge("retryable", "right");
    const availableL = boxEdge("available", "left");
    const availableR = boxEdge("available", "right");
    const executingL = boxEdge("executing", "left");
    const executingR = boxEdge("executing", "right");
    const completed = boxEdge("completed", "left");
    const cancelled = boxEdge("cancelled", "left");
    const discarded = boxEdge("discarded", "left");

    const data = this.el.dataset;
    const entrySuspended = data.entrySuspended === "true";
    const entryScheduled = data.entryScheduled === "true";
    const entryRetryable = data.entryRetryable === "true";
    const engaged = data.engaged === "true";

    const curvePath = (from, to) => {
      const midX = (from.x + to.x) / 2;
      return `M ${from.x} ${from.y} C ${midX} ${from.y}, ${midX} ${to.y}, ${to.x} ${to.y}`;
    };

    const linePath = (from, to) => `M ${from.x} ${from.y} L ${to.x} ${to.y}`;

    const verticalPath = (from, to) => `M ${from.x} ${from.y} L ${to.x} ${to.y}`;

    const paths = [
      { d: verticalPath(suspendedB, scheduledT), active: entrySuspended },
      { d: linePath(scheduled, availableL), active: (entryScheduled || entrySuspended) && engaged },
      { d: curvePath(retryable, availableL), active: entryRetryable && engaged },
      { d: linePath(availableR, executingL), active: engaged },
      { d: curvePath(executingR, completed), active: data.terminalCompleted === "true" },
      { d: linePath(executingR, cancelled), active: data.terminalCancelled === "true" },
      { d: curvePath(executingR, discarded), active: data.terminalDiscarded === "true" },
    ];

    svg.innerHTML = "";
    svg.setAttribute("width", containerRect.width);
    svg.setAttribute("height", containerRect.height);

    paths.forEach(({ d, active }) => {
      const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
      path.setAttribute("d", d);
      path.setAttribute("fill", "none");
      path.setAttribute("stroke-width", "2");
      path.setAttribute("class", active ? "stroke-gray-400 dark:stroke-gray-500" : "stroke-gray-300 dark:stroke-gray-600");
      if (!active) path.setAttribute("stroke-dasharray", "6 4");
      svg.appendChild(path);
    });
  },
};

export default TimelineConnectors;
