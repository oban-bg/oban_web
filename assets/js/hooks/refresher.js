import { load, store } from "../lib/settings"

const Refresher = {
  mounted() {
    const targ = "#refresh-selector"
    const storedRefresh = load("refresh")

    if (storedRefresh !== undefined) {
      this.pushEventTo(targ, "select-refresh", { interval: storedRefresh })
    }

    this.handleVisibility = () => {
      if (document.visibilityState === "visible") {
        this.pushEventTo(targ, "resume-refresh", {})
      } else {
        this.pushEventTo(targ, "pause-refresh", {})
      }
    }

    document.addEventListener("visibilitychange", this.handleVisibility)

    this.handleEvent("update-refresh", ({ refresh }) => {
      store("refresh", refresh)
    })
  },

  destroyed() {
    document.removeEventListener("visibilitychange", this.handleVisibility)
  },
}

export default Refresher
