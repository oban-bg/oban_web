import { load, store } from "../lib/settings"

const Refresher = {
  mounted() {
    const targ = "#refresh-selector"
    const storedRefresh = load("refresh")

    if (storedRefresh !== undefined) {
      this.pushEventTo(targ, "select-refresh", { interval: storedRefresh })
    }

    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "visible") {
        this.pushEventTo(targ, "resume-refresh", {})
      } else {
        this.pushEventTo(targ, "pause-refresh", {})
      }
    })

    this.handleEvent("update-refresh", ({ refresh }) => {
      store("refresh", refresh)
    })
  },
}

export default Refresher
