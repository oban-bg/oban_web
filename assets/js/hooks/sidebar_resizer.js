import { load, store } from "../lib/settings";

const STORAGE_KEY = "sidebar-width";
const DEFAULT_WIDTH = 320; // w-xs
const MIN_WIDTH = 256; // w-3xs
const MAX_WIDTH = 512; // w-lg

const SidebarResizer = {
  mounted() {
    this.sidebar = this.el;
    this.handle = this.sidebar.querySelector("[data-resize-handle]");
    this.isResizing = false;
    this.startX = 0;
    this.startWidth = 0;

    this.setWidth(load(STORAGE_KEY) || DEFAULT_WIDTH);

    this.handleMouseDown = this.handleMouseDown.bind(this);
    this.handleMouseMove = this.handleMouseMove.bind(this);
    this.handleMouseUp = this.handleMouseUp.bind(this);

    this.handle.addEventListener("mousedown", this.handleMouseDown);
  },

  destroyed() {
    this.handle.removeEventListener("mousedown", this.handleMouseDown);
    document.removeEventListener("mousemove", this.handleMouseMove);
    document.removeEventListener("mouseup", this.handleMouseUp);
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

    store(STORAGE_KEY, this.sidebar.offsetWidth);
  },

  setWidth(width) {
    const clampedWidth = Math.max(MIN_WIDTH, Math.min(MAX_WIDTH, width));

    this.sidebar.style.width = `${clampedWidth}px`;
  },
};

export default SidebarResizer;
