import dagre from "dagre";
import { STATE_COLORS } from "../lib/colors";

// Background colors for nodes (light/dark mode)
// Must match progress bar colors in detail_component.ex
const STATE_BG = {
  scheduled: { light: "#eef2ff", dark: "#1e1b4b" },   // indigo
  available: { light: "#eff6ff", dark: "#1e3a8a" },   // blue
  retryable: { light: "#fefce8", dark: "#713f12" },   // yellow
  executing: { light: "#ecfdf5", dark: "#064e3b" },   // emerald
  completed: { light: "#ecfeff", dark: "#164e63" },   // cyan
  cancelled: { light: "#f5f3ff", dark: "#2e1065" },   // violet
  discarded: { light: "#fff1f2", dark: "#4c0519" },   // rose
  pending: { light: "#f9fafb", dark: "#1f2937" },     // gray
};

const NODE_WIDTH = 260;
const NODE_HEIGHT = 56;
const ARROW_SIZE = 8;
const ICON_SIZE = 20;

const ZOOM_LEVELS = [0.5, 0.75, 1, 1.25];
const DEFAULT_ZOOM_INDEX = 2; // 1x zoom

const WorkflowGraph = {
  mounted() {
    this.pan = { x: 0, y: 0 };
    this.isPanning = false;
    this.startPan = { x: 0, y: 0 };
    this.startMouse = { x: 0, y: 0 };
    this.graphData = null;
    this.zoomIndex = DEFAULT_ZOOM_INDEX;
    this.needsInitialCenter = true;
    this.trackActiveNode = true;
    this.lastTrackedNodeId = null;
    this.direction = "LR"; // "LR" (left-right) or "TB" (top-bottom)

    this.applyDotGridBackground();
    this.setupPanning();
    this.createControls();

    // Listen for graph data from server
    this.handleEvent("graph-data", (data) => {
      this.graphData = data;
      this.render();
    });

    // Listen for theme changes
    this.themeObserver = new MutationObserver(() => {
      this.applyDotGridBackground();
      this.updateControlColors();
      if (this.graphData) this.render();
    });
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    });
  },

  destroyed() {
    this.removePanningListeners();
    if (this.themeObserver) {
      this.themeObserver.disconnect();
    }
    if (this.panAnimation) {
      cancelAnimationFrame(this.panAnimation);
    }
  },

  applyDotGridBackground() {
    const isDark = this.isDarkMode();
    const bgColor = isDark ? "#111827" : "#f9fafb";
    const dotColor = isDark ? "#374151" : "#d1d5db";
    this.el.style.backgroundColor = bgColor;
    this.el.style.backgroundImage = `radial-gradient(circle, ${dotColor} 1px, transparent 1px)`;
    this.el.style.backgroundSize = "20px 20px";
  },

  isDarkMode() {
    return document.documentElement.classList.contains("dark");
  },

  getStateColors(state) {
    const borderColor = STATE_COLORS[state] || STATE_COLORS.available;
    const isDark = this.isDarkMode();
    const bg = STATE_BG[state] || STATE_BG.pending;
    const bgColor = isDark ? bg.dark : bg.light;

    return { border: borderColor, bg: bgColor };
  },

  render() {
    const container = this.el;
    const data = this.graphData;

    if (!data) return;

    const { jobs, sub_workflows: subWorkflows } = data;

    if (jobs.length === 0 && subWorkflows.length === 0) {
      this.renderEmpty(container);
      return;
    }

    // Create dagre graph
    const graph = new dagre.graphlib.Graph();
    graph.setGraph({ rankdir: this.direction, nodesep: 20, ranksep: 50, marginx: 30, marginy: 20 });
    graph.setDefaultEdgeLabel(() => ({}));

    // Build a map of job name -> job for dependency resolution
    // deps array contains job names from meta.name
    const jobsByName = new Map();
    jobs.forEach((job) => {
      const name = job.meta?.name;
      if (name) {
        jobsByName.set(name, job);
      }
    });

    // Add job nodes
    jobs.forEach((job) => {
      const displayName = this.getDisplayName(job);
      graph.setNode(`job-${job.id}`, {
        displayName: displayName,
        width: NODE_WIDTH,
        height: NODE_HEIGHT,
        type: "job",
        job: job,
      });
    });

    // Build a map of sub-workflow ID -> sub-workflow for dependency resolution
    const subWorkflowsById = new Map();
    subWorkflows.forEach((sub) => {
      subWorkflowsById.set(sub.workflow_id, sub);
    });

    // Add sub-workflow nodes and edges to parent jobs
    subWorkflows.forEach((sub) => {
      graph.setNode(`sub-${sub.workflow_id}`, {
        label: sub.sub_name || sub.workflow_name || sub.workflow_id.slice(0, 8) + "...",
        width: NODE_WIDTH,
        height: NODE_HEIGHT,
        type: "sub_workflow",
        subWorkflow: sub,
      });

      // Connect sub-workflow to parent job via parent_dep (extracted from sub-workflow's deps)
      if (sub.parent_dep) {
        const parentJob = jobsByName.get(sub.parent_dep);
        if (parentJob) {
          graph.setEdge(`job-${parentJob.id}`, `sub-${sub.workflow_id}`, { suspended: false });
        }
      }
    });

    // Add edges based on dependencies
    // Deps can be:
    // - Simple strings: ["job_name"] - same workflow dependency
    // - Arrays: [["workflow_id", "job_name"]] - cross-workflow dependency
    // - Arrays with splat: [["sub_workflow_id", "*"]] - depends on entire sub-workflow
    jobs.forEach((job) => {
      const deps = job.meta?.deps || [];
      deps.forEach((dep) => {
        const isSuspended = job.state === "scheduled" && deps.length > 0;

        if (Array.isArray(dep)) {
          // Cross-workflow dependency: ["workflow_id", "name"] or ["workflow_id", "*"]
          const [depWorkflowId, depName] = dep;

          if (depName === "*") {
            // Depends on entire sub-workflow
            const subWorkflow = subWorkflowsById.get(depWorkflowId);
            if (subWorkflow) {
              graph.setEdge(`sub-${depWorkflowId}`, `job-${job.id}`, { suspended: isSuspended });
            }
          } else {
            // Depends on specific job in another workflow (parent workflow)
            // This is for sub-workflow jobs depending on parent jobs - skip for now
            // as we handle this via the sub_name connection
          }
        } else {
          // Simple same-workflow dependency
          const depJob = jobsByName.get(dep);
          if (depJob) {
            graph.setEdge(`job-${depJob.id}`, `job-${job.id}`, { suspended: isSuspended });
          }
        }
      });
    });

    // Layout
    dagre.layout(graph);

    // Compute bounds
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    graph.nodes().forEach((nodeId) => {
      const node = graph.node(nodeId);
      minX = Math.min(minX, node.x - node.width / 2);
      minY = Math.min(minY, node.y - node.height / 2);
      maxX = Math.max(maxX, node.x + node.width / 2);
      maxY = Math.max(maxY, node.y + node.height / 2);
    });

    const graphWidth = maxX - minX + 60;
    const graphHeight = maxY - minY + 40;

    // Get container dimensions
    const svg = container.querySelector("svg");
    const containerRect = container.getBoundingClientRect();
    const viewWidth = containerRect.width;
    const viewHeight = containerRect.height;

    // Store bounds for panning/zooming
    this.bounds = { minX: minX - 30, minY: minY - 20, width: graphWidth, height: graphHeight };
    this.viewSize = { width: viewWidth, height: viewHeight };

    // Center graph on initial render
    if (this.needsInitialCenter) {
      this.centerGraph();
      this.needsInitialCenter = false;
    }

    // Track active node if enabled
    if (this.trackActiveNode) {
      this.centerOnActiveNode(graph);
    }

    // Build SVG content
    const svgContent = this.buildSvgContent(graph, minX - 30, minY - 20);

    svg.innerHTML = svgContent;
    this.updateViewBox();

    // Store graph reference for tracking
    this.currentGraph = graph;

    // Add click handlers
    this.setupClickHandlers(svg);
  },

  renderEmpty(container) {
    const svg = container.querySelector("svg");
    const isDark = this.isDarkMode();
    const textColor = isDark ? "#6b7280" : "#9ca3af";

    svg.innerHTML = `
      <text x="50%" y="50%" text-anchor="middle" dominant-baseline="middle"
            fill="${textColor}" font-size="14">
        No jobs to display
      </text>
    `;
  },

  getJobName(job) {
    return job.meta?.handler || job.worker;
  },

  getDisplayName(job) {
    const name = job.meta?.name;
    const worker = job.meta?.decorated_name || job.meta?.handler || job.worker || "Unknown";

    // Truncate name if too long (from right)
    const maxNameLen = 28;
    const truncatedName = name.length > maxNameLen
      ? name.slice(0, maxNameLen - 1) + "…"
      : name;

    // Truncate worker if too long (from left, to preserve module/function name)
    const maxWorkerLen = 32;
    const truncatedWorker = worker.length > maxWorkerLen
      ? "…" + worker.slice(-(maxWorkerLen - 1))
      : worker;

    return { name: truncatedName, worker: truncatedWorker };
  },

  truncateWorkflowId(workflowId) {
    if (!workflowId || workflowId.length <= 20) {
      return `Sub ${workflowId}`;
    }
    // Show first 6 and last 12 characters: "Sub 019cb3…a51ab36fde"
    return `Sub ${workflowId.slice(0, 6)}…${workflowId.slice(-12)}`;
  },

  buildSvgContent(graph, offsetX, offsetY) {
    let content = "";
    const isDark = this.isDarkMode();

    // Define reusable icons and styles
    content += `
      <defs>
        <style>
          .workflow-node {
            transition: filter 0.15s ease;
          }
          .workflow-node:hover {
            filter: brightness(1.08) drop-shadow(0 2px 4px rgba(0, 0, 0, 0.15));
          }
        </style>
        <symbol id="icon-ellipsis" viewBox="0 0 24 24">
          <path fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"
                d="M8.625 12a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm0 0H8.25m4.125 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm0 0H12m4.125 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm0 0h-.375M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/>
        </symbol>
        <symbol id="icon-check" viewBox="0 0 24 24">
          <path fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"
                d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </symbol>
        <symbol id="icon-spinner" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="1.5" opacity="0.25"/>
          <path fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"
                d="M12 3a9 9 0 0 1 9 9">
            <animateTransform attributeName="transform" type="rotate" from="0 12 12" to="360 12 12" dur="1s" repeatCount="indefinite"/>
          </path>
        </symbol>
        <symbol id="icon-document-check" viewBox="0 0 24 24">
          <path fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"
                d="M10.125 2.25h-4.5c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Zm0 0A9 9 0 0 1 19.5 11.25M10.125 2.25c.621 0 1.125.504 1.125 1.125v3.75c0 .621.504 1.125 1.125 1.125h3.75c.621 0 1.125.504 1.125 1.125M9 15l2.25 2.25L15 12"/>
        </symbol>
        <symbol id="icon-arrow-path" viewBox="0 0 24 24">
          <path fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"
                d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182m0-4.991v4.99"/>
        </symbol>
      </defs>
    `;

    // Draw edges first (so they're behind nodes)
    graph.edges().forEach((edge) => {
      const edgeData = graph.edge(edge);
      const sourceNode = graph.node(edge.v);
      const targetNode = graph.node(edge.w);

      if (!sourceNode || !targetNode) return;

      const strokeColor = isDark ? "#4b5563" : "#9ca3af";
      const dashArray = edgeData.suspended ? "6 4" : "none";

      let path, arrowPoints;

      if (this.direction === "TB") {
        // Top-to-bottom: edges go from bottom of source to top of target
        const startX = sourceNode.x;
        const startY = sourceNode.y + sourceNode.height / 2;
        const endY = targetNode.y - targetNode.height / 2 - ARROW_SIZE;
        const endX = targetNode.x;
        const arrowY = targetNode.y - targetNode.height / 2;

        const midY = (startY + arrowY) / 2;
        path = `M ${startX} ${startY} C ${startX} ${midY}, ${endX} ${midY}, ${endX} ${endY}`;

        // Arrow pointing down
        arrowPoints = `${endX},${arrowY} ${endX - ARROW_SIZE / 2},${arrowY - ARROW_SIZE} ${endX + ARROW_SIZE / 2},${arrowY - ARROW_SIZE}`;
      } else {
        // Left-to-right: edges go from right of source to left of target
        const startX = sourceNode.x + sourceNode.width / 2;
        const startY = sourceNode.y;
        const endX = targetNode.x - targetNode.width / 2 - ARROW_SIZE;
        const endY = targetNode.y;
        const arrowX = targetNode.x - targetNode.width / 2;

        const midX = (startX + arrowX) / 2;
        path = `M ${startX} ${startY} C ${midX} ${startY}, ${midX} ${endY}, ${endX} ${endY}`;

        // Arrow pointing right
        arrowPoints = `${arrowX},${endY} ${arrowX - ARROW_SIZE},${endY - ARROW_SIZE / 2} ${arrowX - ARROW_SIZE},${endY + ARROW_SIZE / 2}`;
      }

      content += `<path d="${path}" fill="none" stroke="${strokeColor}" stroke-width="2" stroke-dasharray="${dashArray}" />`;
      content += `<polygon points="${arrowPoints}" fill="${strokeColor}" />`;
    });

    // Draw nodes
    graph.nodes().forEach((nodeId) => {
      const node = graph.node(nodeId);
      const nodeX = node.x - node.width / 2;
      const nodeY = node.y - node.height / 2;

      if (node.type === "job") {
        content += this.renderJobNode(node, nodeX, nodeY, nodeId);
      } else if (node.type === "sub_workflow") {
        content += this.renderSubWorkflowNode(node, nodeX, nodeY, nodeId);
      }
    });

    return content;
  },

  renderJobNode(node, nodeX, nodeY, nodeId) {
    const job = node.job;
    const colors = this.getStateColors(job.state);
    const isDark = this.isDarkMode();
    const textColor = isDark ? "#e5e7eb" : "#374151";
    const dimTextColor = isDark ? "#9ca3af" : "#6b7280";
    const iconX = nodeX + 12 + ICON_SIZE / 2;
    const iconY = nodeY + node.height / 2;
    const textX = nodeX + 12 + ICON_SIZE + 8;
    const displayName = node.displayName;

    // Check if this is a context job (name is "context" and has context: true in meta)
    const isContextJob = job.meta?.name === "context" && job.meta?.context === true;

    return `
      <g data-job-id="${job.id}" class="cursor-pointer workflow-node" role="button">
        <rect x="${nodeX}" y="${nodeY}" width="${node.width}" height="${node.height}"
              rx="8" fill="${colors.bg}" stroke="${colors.border}" stroke-width="2" />
        ${isContextJob ? this.renderContextIcon(iconX, iconY, colors.border) : this.renderStateIcon(job.state, iconX, iconY)}
        <text x="${textX}" y="${nodeY + node.height / 2 - 7}"
              dominant-baseline="middle" font-size="13" font-weight="500" fill="${textColor}">
          ${this.escapeHtml(displayName.name)}
        </text>
        <text x="${textX}" y="${nodeY + node.height / 2 + 11}"
              dominant-baseline="middle" font-size="11" fill="${dimTextColor}">
          ${this.escapeHtml(displayName.worker)}
        </text>
      </g>
    `;
  },

  renderSubWorkflowNode(node, nodeX, nodeY, nodeId) {
    const sub = node.subWorkflow;
    const colors = this.getStateColors(sub.state);
    const isDark = this.isDarkMode();
    const textColor = isDark ? "#e5e7eb" : "#374151";
    const dimTextColor = isDark ? "#9ca3af" : "#6b7280";
    const iconX = nodeX + 12 + ICON_SIZE / 2;
    const iconY = nodeY + node.height / 2;
    const textX = nodeX + 12 + ICON_SIZE + 8;

    // Show sub_name as primary, truncated workflow_id as secondary
    const primaryLabel = sub.sub_name || sub.workflow_name || "Sub-workflow";
    const secondaryLabel = this.truncateWorkflowId(sub.workflow_id);

    return `
      <g data-workflow-id="${sub.workflow_id}" class="cursor-pointer workflow-node" role="button">
        <rect x="${nodeX}" y="${nodeY}" width="${node.width}" height="${node.height}"
              rx="8" fill="${colors.bg}" stroke="${colors.border}" stroke-width="2" stroke-dasharray="6 3" />
        ${this.renderStateIcon(sub.state, iconX, iconY)}
        <text x="${textX}" y="${nodeY + node.height / 2 - 7}"
              dominant-baseline="middle" font-size="13" font-weight="500" fill="${textColor}">
          ${this.escapeHtml(primaryLabel)}
        </text>
        <text x="${textX}" y="${nodeY + node.height / 2 + 11}"
              dominant-baseline="middle" font-size="11" fill="${dimTextColor}">
          ${this.escapeHtml(secondaryLabel)}
        </text>
      </g>
    `;
  },

  getStateIconId(state) {
    switch (state) {
      case "executing":
        return "icon-spinner";
      case "retryable":
        return "icon-arrow-path";
      case "completed":
      case "cancelled":
      case "discarded":
        return "icon-check";
      default:
        return "icon-ellipsis";
    }
  },

  renderStateIcon(state, centerX, centerY) {
    const colors = this.getStateColors(state);
    const iconId = this.getStateIconId(state);
    const iconX = centerX - ICON_SIZE / 2;
    const iconY = centerY - ICON_SIZE / 2;

    return `<use href="#${iconId}" x="${iconX}" y="${iconY}" width="${ICON_SIZE}" height="${ICON_SIZE}"
                 style="color: ${colors.border}" />`;
  },

  renderContextIcon(centerX, centerY, color) {
    const iconX = centerX - ICON_SIZE / 2;
    const iconY = centerY - ICON_SIZE / 2;

    return `<use href="#icon-document-check" x="${iconX}" y="${iconY}" width="${ICON_SIZE}" height="${ICON_SIZE}"
                 style="color: ${color}" />`;
  },

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  },

  setupClickHandlers(svg) {
    svg.querySelectorAll("[data-job-id]").forEach((element) => {
      element.addEventListener("click", (event) => {
        event.stopPropagation();
        const jobId = element.dataset.jobId;
        this.pushEventTo(this.el, "navigate-to-job", { job_id: jobId });
      });
    });

    svg.querySelectorAll("[data-workflow-id]").forEach((element) => {
      element.addEventListener("click", (event) => {
        event.stopPropagation();
        const workflowId = element.dataset.workflowId;
        this.pushEventTo(this.el, "navigate-to-workflow", { workflow_id: workflowId });
      });
    });
  },

  setupPanning() {
    const svg = this.el.querySelector("svg");

    this.onMouseDown = (event) => {
      if (event.target.closest(".workflow-node")) return;

      this.isPanning = true;
      this.startPan = { ...this.pan };
      this.startMouse = { x: event.clientX, y: event.clientY };
      svg.style.cursor = "grabbing";
      event.preventDefault();
    };

    this.onMouseMove = (event) => {
      if (!this.isPanning) return;

      const zoom = ZOOM_LEVELS[this.zoomIndex];
      const deltaX = (event.clientX - this.startMouse.x) / zoom;
      const deltaY = (event.clientY - this.startMouse.y) / zoom;

      this.pan.x = this.startPan.x + deltaX;
      this.pan.y = this.startPan.y + deltaY;

      this.updateViewBox();
    };

    this.onMouseUp = () => {
      this.isPanning = false;
      this.el.querySelector("svg").style.cursor = "grab";
    };

    svg.addEventListener("mousedown", this.onMouseDown);
    document.addEventListener("mousemove", this.onMouseMove);
    document.addEventListener("mouseup", this.onMouseUp);

    svg.style.cursor = "grab";
  },

  removePanningListeners() {
    document.removeEventListener("mousemove", this.onMouseMove);
    document.removeEventListener("mouseup", this.onMouseUp);
  },

  updateViewBox() {
    const svg = this.el.querySelector("svg");
    if (!this.bounds || !this.viewSize) return;

    const zoom = ZOOM_LEVELS[this.zoomIndex];
    const scaledWidth = this.viewSize.width / zoom;
    const scaledHeight = this.viewSize.height / zoom;

    svg.setAttribute("viewBox",
      `${this.bounds.minX - this.pan.x} ${this.bounds.minY - this.pan.y} ${scaledWidth} ${scaledHeight}`
    );
    svg.style.width = "100%";
    svg.style.height = "100%";
  },

  centerGraph() {
    if (!this.bounds || !this.viewSize) return;

    const zoom = ZOOM_LEVELS[this.zoomIndex];
    const scaledWidth = this.viewSize.width / zoom;
    const scaledHeight = this.viewSize.height / zoom;

    if (this.direction === "TB") {
      // Top-bottom: center horizontally, start at top
      this.pan.x = (scaledWidth - this.bounds.width) / 2;
      this.pan.y = 20;
    } else {
      // Left-right: start at left, center vertically
      this.pan.x = 20;
      this.pan.y = (scaledHeight - this.bounds.height) / 2;
    }
  },

  zoomIn() {
    if (this.zoomIndex < ZOOM_LEVELS.length - 1) {
      this.zoomIndex++;
      this.updateViewBox();
    }
  },

  zoomOut() {
    if (this.zoomIndex > 0) {
      this.zoomIndex--;
      this.updateViewBox();
    }
  },

  resetView() {
    this.zoomIndex = DEFAULT_ZOOM_INDEX;
    this.centerGraph();
    this.updateViewBox();
  },

  toggleTracking() {
    this.trackActiveNode = !this.trackActiveNode;
    this.updateTrackingButtonState();

    if (this.trackActiveNode && this.currentGraph) {
      // Reset so we immediately focus on current active node (no animation on toggle)
      this.lastTrackedNodeId = null;
      this.centerOnActiveNode(this.currentGraph, false);
      this.updateViewBox();
    }
  },

  centerOnActiveNode(graph, animate = true) {
    if (!this.bounds || !this.viewSize) return;

    // Find executing node (job or sub-workflow)
    let activeNode = null;
    let activeNodeId = null;
    graph.nodes().forEach((nodeId) => {
      const node = graph.node(nodeId);
      const state = node.type === "job" ? node.job.state : node.subWorkflow?.state;
      if (state === "executing") {
        activeNode = node;
        activeNodeId = nodeId;
      }
    });

    // Don't move if no active node, or if it's the same node we're already tracking
    if (!activeNode || activeNodeId === this.lastTrackedNodeId) return;

    this.lastTrackedNodeId = activeNodeId;

    const zoom = ZOOM_LEVELS[this.zoomIndex];
    const scaledWidth = this.viewSize.width / zoom;
    const scaledHeight = this.viewSize.height / zoom;

    // Target pan position to center on the active node
    const targetX = scaledWidth / 2 - (activeNode.x - this.bounds.minX);
    const targetY = scaledHeight / 2 - (activeNode.y - this.bounds.minY);

    if (animate) {
      this.animatePanTo(targetX, targetY);
    } else {
      this.pan.x = targetX;
      this.pan.y = targetY;
    }
  },

  animatePanTo(targetX, targetY) {
    if (this.panAnimation) {
      cancelAnimationFrame(this.panAnimation);
    }

    const startX = this.pan.x;
    const startY = this.pan.y;
    const duration = 300; // ms
    const startTime = performance.now();

    const easeOutCubic = (time) => 1 - Math.pow(1 - time, 3);

    const animate = (currentTime) => {
      const elapsed = currentTime - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const eased = easeOutCubic(progress);

      this.pan.x = startX + (targetX - startX) * eased;
      this.pan.y = startY + (targetY - startY) * eased;
      this.updateViewBox();

      if (progress < 1) {
        this.panAnimation = requestAnimationFrame(animate);
      } else {
        this.panAnimation = null;
      }
    };

    this.panAnimation = requestAnimationFrame(animate);
  },

  updateTrackingButtonState() {
    this.updateControlColors();
  },

  createControls() {
    const controls = document.createElement("div");
    controls.className = "absolute bottom-3 right-3 flex flex-col gap-1";
    controls.id = "graph-controls";

    const buttonClass = "w-8 h-8 flex items-center justify-center rounded-md border transition-colors";

    controls.innerHTML = `
      <button id="zoom-in" class="${buttonClass}" title="Zoom in">
        <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607ZM10.5 7.5v6m3-3h-6" />
        </svg>
      </button>
      <button id="zoom-out" class="${buttonClass}" title="Zoom out">
        <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607ZM13.5 10.5h-6" />
        </svg>
      </button>
      <button id="reset-view" class="${buttonClass}" title="Reset view">
        <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 9V4.5M9 9H4.5M9 9 3.75 3.75M9 15v4.5M9 15H4.5M9 15l-5.25 5.25M15 9h4.5M15 9V4.5M15 9l5.25-5.25M15 15h4.5M15 15v4.5m0-4.5 5.25 5.25" />
        </svg>
      </button>
      <button id="toggle-tracking" class="${buttonClass}" title="Track active node">
        <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M7.5 3.75H6A2.25 2.25 0 0 0 3.75 6v1.5M16.5 3.75H18A2.25 2.25 0 0 1 20.25 6v1.5m0 9V18A2.25 2.25 0 0 1 18 20.25h-1.5m-9 0H6A2.25 2.25 0 0 1 3.75 18v-1.5M12 12m-3 0a3 3 0 1 0 6 0 3 3 0 0 0-6 0" />
        </svg>
      </button>
      <button id="toggle-direction" class="${buttonClass}" title="Toggle layout direction"></button>
    `;

    this.el.style.position = "relative";
    this.el.appendChild(controls);
    this.updateControlColors();

    controls.querySelector("#zoom-in").addEventListener("click", () => this.zoomIn());
    controls.querySelector("#zoom-out").addEventListener("click", () => this.zoomOut());
    controls.querySelector("#reset-view").addEventListener("click", () => this.resetView());
    controls.querySelector("#toggle-tracking").addEventListener("click", () => this.toggleTracking());
    controls.querySelector("#toggle-direction").addEventListener("click", () => this.toggleDirection());

    this.updateDirectionIcon();
  },

  toggleDirection() {
    this.direction = this.direction === "LR" ? "TB" : "LR";
    this.needsInitialCenter = true;
    this.updateDirectionIcon();
    if (this.graphData) this.render();
  },

  updateDirectionIcon() {
    const btn = this.el.querySelector("#toggle-direction");
    if (!btn) return;

    // Show icon indicating current direction (bidirectional arrows)
    const icon = this.direction === "LR"
      ? `<svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
           <path stroke-linecap="round" stroke-linejoin="round" d="M7.5 21 3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5" />
         </svg>`
      : `<svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
           <path stroke-linecap="round" stroke-linejoin="round" d="M3 7.5 7.5 3m0 0L12 7.5M7.5 3v13.5m13.5 0L16.5 21m0 0L12 16.5m4.5 4.5V7.5" />
         </svg>`;

    btn.innerHTML = icon;
    btn.title = this.direction === "LR" ? "Layout: left to right" : "Layout: top to bottom";
  },

  updateControlColors() {
    const controls = this.el.querySelector("#graph-controls");
    if (!controls) return;

    const isDark = this.isDarkMode();
    const bgColor = isDark ? "bg-gray-800" : "bg-white";
    const borderColor = isDark ? "border-gray-600" : "border-gray-300";
    const textColor = isDark ? "text-gray-300" : "text-gray-600";
    const hoverBg = isDark ? "hover:bg-gray-700" : "hover:bg-gray-100";

    controls.querySelectorAll("button").forEach((btn) => {
      if (btn.id === "toggle-tracking" && this.trackActiveNode) {
        // Active tracking button gets special styling
        const activeBg = isDark ? "bg-blue-900" : "bg-blue-100";
        const activeBorder = isDark ? "border-blue-500" : "border-blue-400";
        const activeText = isDark ? "text-blue-400" : "text-blue-600";
        btn.className = `w-8 h-8 flex items-center justify-center rounded-md border transition-colors cursor-pointer ${activeBg} ${activeBorder} ${activeText}`;
      } else {
        btn.className = `w-8 h-8 flex items-center justify-center rounded-md border transition-colors cursor-pointer ${bgColor} ${borderColor} ${textColor} ${hoverBg}`;
      }
    });
  },
};

export default WorkflowGraph;
