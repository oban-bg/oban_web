const purgecss = require("@fullhuman/postcss-purgecss")({
  content: [
    "../lib/**/*.eex",
    "../lib/**/*.ex",
    "../lib/**/*.leex"
  ],

  defaultExtractor: content => content.match(/[A-Za-z0-9-_:/]+/g) || []
})

module.exports = {
  plugins: [
    require("tailwindcss"),
    require("autoprefixer"),
    require("cssnano"),
    ...process.env.NODE_ENV === "production"
      ? [purgecss]
      : []
  ]
}
