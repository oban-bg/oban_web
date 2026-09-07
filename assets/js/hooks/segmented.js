// Radio-style keyboard handling for a segmented control: arrows move the selection and home or
// end jump to the edges. Moving selects, as in a native radio group, so the server hears a click.
const Segmented = {
  mounted() {
    this.el.addEventListener("keydown", (event) => {
      const options = Array.from(this.el.querySelectorAll('[role="radio"]:not([disabled])'))
      const index = options.indexOf(document.activeElement)

      if (index === -1) return

      const select = (position) => {
        event.preventDefault()

        const option = options[(position + options.length) % options.length]

        option.focus()
        option.click()
      }

      switch (event.key) {
        case "ArrowRight":
        case "ArrowDown":
          select(index + 1)
          break
        case "ArrowLeft":
        case "ArrowUp":
          select(index - 1)
          break
        case "Home":
          select(0)
          break
        case "End":
          select(options.length - 1)
          break
      }
    })
  },
}

export default Segmented
