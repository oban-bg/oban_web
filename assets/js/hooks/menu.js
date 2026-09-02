// Keyboard behavior for dropdown menus: arrow keys move focus between options, home/end jump to
// the edges, escape closes and restores focus to the toggle, and tab closes on the way out. The
// closing command lives in the menu's `data-close` attribute so the server defines it once.
const Menu = {
  mounted() {
    this.el.addEventListener("keydown", (event) => {
      const options = Array.from(this.el.querySelectorAll("a, button"))

      if (options.length === 0) return

      const index = options.indexOf(document.activeElement)

      const focusAt = (position) => {
        event.preventDefault()
        options[(position + options.length) % options.length].focus()
      }

      switch (event.key) {
        case "ArrowDown":
          focusAt(index + 1)
          break
        case "ArrowUp":
          focusAt(index === -1 ? options.length - 1 : index - 1)
          break
        case "Home":
          focusAt(0)
          break
        case "End":
          focusAt(options.length - 1)
          break
        case "Escape":
          this.close()
          document.getElementById(`${this.el.id}-toggle`)?.focus()
          break
        case "Tab":
          this.close()
          break
      }
    })
  },

  close() {
    const command = this.el.getAttribute("data-close")

    if (command) this.liveSocket.execJS(this.el, command)
  },
}

export default Menu
