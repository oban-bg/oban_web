const colors = require("tailwindcss/colors");

module.exports = {
  mode: 'jit',
  darkMode: 'class',
  theme: {
    fontFamily: {
      sans: ["Inter var", "sans-serif"],
      mono: ["Menlo", "Monaco", "Consolas", "Liberation Mono", "Courier New", "monospace"]
    },
    extend: {
      spacing: {
        "72": "18rem",
        "84": "21rem",
        "96": "24rem"
      }
    },
    colors: {
      transparent: "transparent",
      current: "currentColor",
      black: "#000",
      white: "#fff",
      blue: colors.sky,
      cyan: colors.cyan,
      gray: colors.coolGray,
      green: colors.emerald,
      indigo: colors.indigo,
      pink: colors.pink,
      red: colors.red,
      teal: colors.teal,
      violet: colors.violet,
      yellow: colors.amber
    }
  },
  purge: ["../lib/**/*.*ex"],
  variants: {
    display: ["group-hover"]
  },
  plugins: [
    require('@tailwindcss/forms')
  ]
}
