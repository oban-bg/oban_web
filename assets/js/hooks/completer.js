const Completer = {
  mounted() {
    const input = document.querySelector("#search-input")

    input.addEventListener("keydown", (event) => {
      if (event.key === "Tab") {
        event.preventDefault()

        this.pushEventTo("#search", "complete", {})
      }
    })

    this.handleEvent("completed", ({buffer}) => {
      if (/.+:$/.test(buffer)) {
        input.value = buffer
      } else {
        input.value = ""
      }
    })
  }
}

export default Completer
