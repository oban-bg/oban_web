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
export const STATE_COLORS = {
  scheduled: INDIGO,
  available: BLUE,
  retryable: YELLOW,
  executing: EMERALD,
  completed: CYAN,
  cancelled: VIOLET,
  discarded: ROSE,
}
