import tippy, { roundArrow } from "tippy.js"

const Tippy = {
  mounted() {
    const content = this.el.getAttribute("data-title")

    tippy(this.el, { arrow: roundArrow, content: content, delay: [250, null] })
  }
}

export default Tippy
