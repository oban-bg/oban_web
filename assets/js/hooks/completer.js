const Completer = {
  mounted() {
    const input = document.querySelector("#search-input")

    input.addEventListener("keydown", (event) => {
      if (event.key === "Tab") {
        event.preventDefault()

        this.pushEventTo("#search", "complete", {})
      }

      if (event.key === "Escape") {
        input.blur()

        const node = document.querySelector("#search-suggest")
        const exec = node.getAttribute("phx-click-away")

        this.liveSocket.execJS(node, exec, "click")
      }
    })

    this.handleEvent("completed", ({buffer}) => {
      input.value = buffer
    })
  }
}

export default Completer
