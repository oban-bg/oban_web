const PAIRS = {
  "/": "#search",
  "?": "#shortcuts",
  c: "#nav-crons",
  j: "#nav-jobs",
  p: "#nav-pruners",
  q: "#nav-queues",
  w: "#nav-workflows",
  r: "#refresh-selector",
  t: "#theme-selector",
}

const EDITABLE = ["INPUT", "TEXTAREA", "SELECT"]

const Shortcuts = {
  mounted() {
    // The listener lives on the window, so it has to be removed on unmount or every reconnect
    // stacks another copy and a single key press fires the shortcut repeatedly.
    this.handleKeydown = (event) => {
      if (EDITABLE.includes(event.target.nodeName) || event.target.isContentEditable) return
      if (event.metaKey || event.ctrlKey || event.altKey) return

      const selector = PAIRS[event.key]

      if (selector) {
        event.preventDefault()

        const node = document.querySelector(selector)
        const exec = node.getAttribute("data-shortcut")

        this.liveSocket.execJS(node, exec, "click")
      }
    }

    window.addEventListener("keydown", this.handleKeydown)
  },

  destroyed() {
    window.removeEventListener("keydown", this.handleKeydown)
  },
}

export default Shortcuts
