import { load, store } from "../lib/settings";

const STORAGE_KEY = "sidebar_width";
const MIN_WIDTH = 256; // w-3xs
const MAX_WIDTH = 512; // w-lg

const SidebarResizer = {
  mounted() {
    this.sidebar = this.el;
    this.isResizing = false;
    this.startX = 0;
    this.startWidth = 0;

    this.handleMouseDown = this.handleMouseDown.bind(this);
    this.handleMouseMove = this.handleMouseMove.bind(this);
    this.handleMouseUp = this.handleMouseUp.bind(this);

    this.attachHandle();
  },

  updated() {
    this.attachHandle();
  },

  destroyed() {
    this.detachHandle();
    document.removeEventListener("mousemove", this.handleMouseMove);
    document.removeEventListener("mouseup", this.handleMouseUp);
  },

  attachHandle() {
    if (this.handle) {
      this.handle.removeEventListener("mousedown", this.handleMouseDown);
    }

    this.handle = this.sidebar.querySelector("[data-resize-handle]");

    if (this.handle) {
      this.handle.addEventListener("mousedown", this.handleMouseDown);
    }
  },

  detachHandle() {
    if (this.handle) {
      this.handle.removeEventListener("mousedown", this.handleMouseDown);
    }
  },

  handleMouseDown(event) {
    event.preventDefault();

    this.isResizing = true;
    this.startX = event.clientX;
    this.startWidth = this.sidebar.offsetWidth;

    document.addEventListener("mousemove", this.handleMouseMove);
    document.addEventListener("mouseup", this.handleMouseUp);

    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
    this.handle.classList.add("resizing");

    // Pause refresh while resizing to prevent handle from resetting
    this.pushEventTo("#refresh-selector", "pause-refresh", {});
  },

  handleMouseMove(event) {
    if (!this.isResizing) return;

    const delta = event.clientX - this.startX;

    this.setWidth(this.startWidth + delta);
  },

  handleMouseUp() {
    if (!this.isResizing) return;

    this.isResizing = false;

    document.removeEventListener("mousemove", this.handleMouseMove);
    document.removeEventListener("mouseup", this.handleMouseUp);

    document.body.style.cursor = "";
    document.body.style.userSelect = "";
    this.handle.classList.remove("resizing");

    const width = this.sidebar.offsetWidth;
    store(STORAGE_KEY, width);

    this.pushEvent("sidebar_resize", { width });

    // Resume refresh after resizing
    this.pushEventTo("#refresh-selector", "resume-refresh", {});
  },

  setWidth(width) {
    const clampedWidth = Math.max(MIN_WIDTH, Math.min(MAX_WIDTH, width));

    document.documentElement.style.setProperty("--sidebar-width", `${clampedWidth}px`);
  },
};

export default SidebarResizer;
