const plugin = require("tailwindcss/plugin")
const fs = require("fs");
const path = require("path");

module.exports = plugin(function ({ matchComponents, theme }) {
  let iconsDir = path.join(process.cwd(), "icons");
  let values = {};
  let icons = [
    ["", "outline"],
    ["-solid", "solid"],
    ["-special", "special"],
  ];

  icons.forEach(([suffix, dir]) => {
    let dirPath = path.join(iconsDir, dir);

    fs.readdirSync(dirPath).forEach((file) => {
      if (!file.endsWith(".svg")) return;

      let name = path.basename(file, ".svg") + suffix;
      values[name] = { name, fullPath: path.join(dirPath, file) };
    });
  });

  matchComponents(
    {
      icon: ({ name, fullPath }) => {
        let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
        content = encodeURIComponent(content)

        return {
          [`--icon-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
          "-webkit-mask": `var(--icon-${name})`,
          "mask": `var(--icon-${name})`,
          "background-color": "currentColor",
          "vertical-align": "middle",
          "display": "inline-block",
          "width": theme("spacing.6"),
          "height": theme("spacing.6"),
        };
      },
    },
    { values },
  );
});
