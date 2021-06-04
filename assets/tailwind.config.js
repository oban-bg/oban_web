module.exports = {
  darkMode: 'media',
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
  purge: [
    "../lib/**/*.eex",
    "../lib/**/*.ex",
    "../lib/**/*.leex"
  ],
  variants: {
    display: ["group-hover"]
  },
  plugins: [
    require('@tailwindcss/forms')
  ]
}
