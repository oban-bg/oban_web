import { load, store } from "../lib/settings"

const THEMES = ["light", "dark", "system"]

const ChangeTheme = {
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
    this.el.addEventListener("click", () => {
      const theme = this.el.getAttribute("value")

      store("theme", theme)

      this.applyTheme()

      this.pushEventTo("#theme-selector", "restore", { theme: theme })
    })
  },
}

const RestoreTheme = {
  mounted() {
    if (load("theme")) {
      this.pushEventTo("#theme-selector", "restore", { theme: load("theme") })
    }

    this.handleEvent("cycle-theme", () => {
      const index = THEMES.indexOf(load("theme")) + 1
      const theme = THEMES[index % THEMES.length]

      store("theme", theme)

      ChangeTheme.applyTheme()

      this.pushEventTo("#theme-selector", "restore", { theme: theme })
    })
  },
}

export { ChangeTheme, RestoreTheme }
