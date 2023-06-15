import { load, store } from "../lib/settings"

const Refresher = {
  mounted() {
    const targ = "#refresh-selector"
    const elem = this

    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "visible") {
        elem.pushEventTo(targ, "resume-refresh", {})
      } else {
        elem.pushEventTo(targ, "pause-refresh", {})
      }
    })

    const refresh = load("refresh")

    if (refresh) {
      elem.pushEventTo(targ, "select-refresh", { value: refresh })
    }

    this.handleEvent("update-refresh", ({ refresh }) => {
      store("refresh", refresh)
    })
  },
}

export default Refresher
