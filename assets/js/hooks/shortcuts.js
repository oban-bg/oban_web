const PAIRS = {
  "/": "#search",
  "?": "#shortcuts",
  J: "#nav-jobs",
  Q: "#nav-queues",
  r: "#refresh-selector",
  t: "#theme-selector",
}

const Shortcuts = {
  mounted() {
    window.addEventListener("keydown", (event) => {
      if (event.target.nodeName !== "BODY") return
      if (event.metaKey) return

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
