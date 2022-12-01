const colors = require("tailwindcss/colors");

module.exports = {
  darkMode: "class",
  theme: {
    fontFamily: {
      sans: ["Inter var", "sans-serif"],
      mono: ["Menlo", "Monaco", "Consolas", "Liberation Mono", "Courier New", "monospace"]
    },
    extend: {
      colors: {
        gray: {
          950: "#0D1320"
        }
      },
      spacing: {
        "72": "18rem",
        "84": "21rem",
        "96": "24rem"
      }
    },
    colors: {
      transparent: "transparent",
      current: "currentColor",
      black: colors.black,
      white: colors.white,
      blue: colors.sky,
      cyan: colors.cyan,
      gray: colors.gray,
      green: colors.emerald,
      indigo: colors.indigo,
      orange: colors.orange,
      pink: colors.pink,
      red: colors.red,
      teal: colors.teal,
      violet: colors.violet,
      yellow: colors.amber,
      slate: colors.slate
    }
  },
  content: ["../lib/**/*.*ex"],
  variants: {
    display: ["group-hover"]
  },
  plugins: [
    require("@tailwindcss/forms")
  ]
}
