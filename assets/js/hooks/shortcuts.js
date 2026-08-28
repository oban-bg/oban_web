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
    window.addEventListener("keydown", (event) => {
      if (EDITABLE.includes(event.target.nodeName) || event.target.isContentEditable) return
      if (event.metaKey || event.ctrlKey || event.altKey) return

      const selector = PAIRS[event.key]

      if (selector) {
        event.preventDefault()

        const node = document.querySelector(selector)
        const exec = node.getAttribute("data-shortcut")

        this.liveSocket.execJS(node, exec, "click")
      }
    })
  },
}

export default Shortcuts
