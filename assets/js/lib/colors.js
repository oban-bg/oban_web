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

export const OTHER_PALETTE = [CYAN, VIOLET, YELLOW, EMERALD, ORANGE, TEAL, ROSE]

// Must match progress bar colors in detail_component.ex
export const STATE_FG = {
  scheduled: INDIGO,
  available: BLUE,
  retryable: YELLOW,
  executing: EMERALD,
  completed: CYAN,
  cancelled: VIOLET,
  discarded: ROSE,
}

export const STATE_BG = {
  scheduled: { light: "#eef2ff", dark: "#1e1b4b" },
  available: { light: "#eff6ff", dark: "#1e3a8a" },
  retryable: { light: "#fefce8", dark: "#713f12" },
  executing: { light: "#ecfdf5", dark: "#064e3b" },
  completed: { light: "#ecfeff", dark: "#164e63" },
  cancelled: { light: "#f5f3ff", dark: "#2e1065" },
  discarded: { light: "#fff1f2", dark: "#4c0519" },
  pending: { light: "#f9fafb", dark: "#1f2937" },
}
