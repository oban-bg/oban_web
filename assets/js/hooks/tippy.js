import tippy, { roundArrow } from "tippy.js"

const Tippy = {
  destroyed() {
    this.tippy.destroy()
  },

  mounted() {
    const content = this.el.getAttribute("data-title")

    this.tippy = tippy(this.el, { arrow: roundArrow, content: content, delay: [250, null] })
  },
}

export default Tippy
