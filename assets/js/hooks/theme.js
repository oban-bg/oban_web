const THEMES = ["light", "dark", "system"]

const ChangeTheme = {
  applyTheme() {
    const wantsDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    const noPreference = !("theme" in localStorage)

    if (
      localStorage.theme === "dark" ||
      (localStorage.theme === "system" && wantsDark) ||
      (noPreference && wantsDark)
    ) {
      document.documentElement.classList.add("dark")
    } else {
      document.documentElement.classList.remove("dark")
    }
  },

  mounted() {
    this.el.addEventListener("click", () => {
      const theme = this.el.getAttribute("value")

      localStorage.theme = theme

      this.applyTheme()

      this.pushEventTo("#theme-selector", "restore", { theme: theme })
    })
  },
}

const RestoreTheme = {
  mounted() {
    this.pushEventTo("#theme-selector", "restore", {
      theme: localStorage.theme
    })

    this.handleEvent("cycle-theme", () => {
      const index = THEMES.indexOf(localStorage.theme) + 1
      const theme = THEMES[index % THEMES.length]

      localStorage.theme = theme

      ChangeTheme.applyTheme()

      this.pushEventTo("#theme-selector", "restore", { theme: theme })
    })
  },
}

export { ChangeTheme, RestoreTheme }
