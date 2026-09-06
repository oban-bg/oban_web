const Completer = {
  mounted() {
    this.input = this.el.querySelector("#search-input")

    this.input.addEventListener("keydown", (event) => this.keydown(event))

    this.handleEvent("completed", ({ buffer }) => {
      this.input.value = buffer
    })
  },

  // Suggestions re-render whenever the buffer changes, so any active option is stale.
  updated() {
    this.activate(null)
  },

  options() {
    return Array.from(this.el.querySelectorAll("#search-options [role=option]"))
  },

  activate(option) {
    for (const node of this.options()) {
      node.setAttribute("aria-selected", node === option ? "true" : "false")
    }

    if (option) {
      this.input.setAttribute("aria-activedescendant", option.id)
      option.scrollIntoView({ block: "nearest" })
    } else {
      this.input.removeAttribute("aria-activedescendant")
    }
  },

  reopen() {
    const suggest = this.el.querySelector("#search-suggest")

    if (getComputedStyle(suggest).display === "none") {
      this.liveSocket.execJS(this.input, this.input.getAttribute("phx-focus"), "focus")
    }
  },

  keydown(event) {
    const options = this.options()
    const active = this.el.querySelector("#search-options [aria-selected=true]")
    const index = options.indexOf(active)

    switch (event.key) {
      case "Tab":
        if (event.shiftKey || this.input.value.trim() === "" || options.length === 0) return

        event.preventDefault()
        this.pushEventTo("#search", "complete", {})
        break

      case "ArrowDown":
        if (options.length === 0) return

        event.preventDefault()
        this.reopen()
        this.activate(options[(index + 1) % options.length])
        break

      case "ArrowUp":
        if (options.length === 0) return

        event.preventDefault()
        this.reopen()
        this.activate(options[index <= 0 ? options.length - 1 : index - 1])
        break

      case "Enter":
        if (!active) return

        event.preventDefault()
        active.click()
        break

      case "Escape": {
        this.input.blur()

        const node = this.el.querySelector("#search-suggest")
        const exec = node.getAttribute("phx-click-away")

        this.liveSocket.execJS(node, exec, "click")
        break
      }
    }
  },
}

export default Completer
