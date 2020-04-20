module.exports = {
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
    }
  },
  variants: {},
  plugins: [
    require("@tailwindcss/ui")
  ],
}
