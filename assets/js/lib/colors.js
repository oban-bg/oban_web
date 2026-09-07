// Tailwind color palette
export const BLUE = "#60a5fa" // blue-400
export const CYAN = "#22d3ee" // cyan-400
export const EMERALD = "#34d399" // emerald-400
export const INDIGO = "#818cf8" // indigo-400
export const ORANGE = "#fb923c" // orange-400
export const ROSE = "#fb7185" // rose-400
export const TEAL = "#2dd4bf" // teal-400
export const VIOLET = "#a78bfa" // violet-400
export const YELLOW = "#facc15" // yellow-400
export const GRAY = "#9ca3af" // gray-400

// A 2px line at the 400 level sits below 3:1 against white, so light-mode strokes step down to
// the same darker levels text uses. Yellow needs 700 to clear the bar; the rest clear it at 600.
// Keys cover the state palette and the non-state series palette from lib/oban/web/colors.ex.
export const LINE_FG = {
  [BLUE]: "#2563eb", // blue-600
  [CYAN]: "#0891b2", // cyan-600
  [EMERALD]: "#059669", // emerald-600
  [INDIGO]: "#4f46e5", // indigo-600
  [ROSE]: "#e11d48", // rose-600
  [VIOLET]: "#7c3aed", // violet-600
  [YELLOW]: "#a16207", // yellow-700
  [GRAY]: "#4b5563", // gray-600
  "#fbbf24": "#d97706", // amber-400 -> amber-600
  "#e879f9": "#c026d3", // fuchsia-400 -> fuchsia-600
  "#a3e635": "#65a30d", // lime-400 -> lime-600
  [ORANGE]: "#ea580c", // orange-600
  "#f472b6": "#db2777", // pink-400 -> pink-600
  "#f87171": "#dc2626", // red-400 -> red-600
  "#38bdf8": "#0284c7", // sky-400 -> sky-600
  [TEAL]: "#0d9488", // teal-600
}

// Must match progress bar colors in detail_component.ex
export const STATE_FG = {
  suspended: GRAY,
  scheduled: INDIGO,
  available: BLUE,
  retryable: YELLOW,
  executing: EMERALD,
  completed: CYAN,
  cancelled: VIOLET,
  discarded: ROSE,
}

export const STATE_BG = {
  suspended: { light: "#f9fafb", dark: "#1f2937" },
  scheduled: { light: "#eef2ff", dark: "#1e1b4b" },
  available: { light: "#eff6ff", dark: "#1e3a8a" },
  retryable: { light: "#fefce8", dark: "#713f12" },
  executing: { light: "#ecfdf5", dark: "#064e3b" },
  completed: { light: "#ecfeff", dark: "#164e63" },
  cancelled: { light: "#f5f3ff", dark: "#2e1065" },
  discarded: { light: "#fff1f2", dark: "#4c0519" },
  pending: { light: "#f9fafb", dark: "#1f2937" },
}
