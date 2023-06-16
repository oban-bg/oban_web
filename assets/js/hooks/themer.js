import { load, store } from "../lib/settings"

const Themer = {
  applyTheme() {
    const wantsDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    const theme = load("theme")

    if (theme === "dark" || (theme === "system" && wantsDark) || (!theme && wantsDark)) {
      document.documentElement.classList.add("dark")
    } else {
      document.documentElement.classList.remove("dark")
    }
  },

  mounted() {
    this.handleEvent("update-theme", ({ theme }) => {
      store("theme", theme)

      this.applyTheme()
    })
  },
}

export default Themer
