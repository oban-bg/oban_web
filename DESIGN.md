---
name: Oban Web
description: A calm, luminous control room for background jobs — realtime state rendered in light.
colors:
  state-available: "#60a5fa"
  state-completed: "#22d3ee"
  state-executing: "#34d399"
  state-scheduled: "#818cf8"
  state-retryable: "#facc15"
  state-cancelled: "#a78bfa"
  state-discarded: "#fb7185"
  state-suspended: "#9ca3af"
  accent-interaction: "#3b82f6"
  accent-brand: "#8b5cf6"
  danger: "#ef4444"
  warning: "#f59e0b"
  canvas-light: "#e5e7eb"
  canvas-dark: "#030712"
  panel-light: "#ffffff"
  panel-dark: "#111827"
  ink-light: "#111827"
  ink-dark: "#f3f4f6"
  muted-light: "#4b5563"
  muted-dark: "#9ca3af"
  border-light: "#e5e7eb"
  border-dark: "#374151"
typography:
  headline:
    fontFamily: "Inter var, sans-serif"
    fontSize: "1rem"
    fontWeight: 600
    lineHeight: 1.5
  body:
    fontFamily: "Inter var, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "Inter var, sans-serif"
    fontSize: "0.75rem"
    fontWeight: 500
    letterSpacing: "0.05em"
  mono:
    fontFamily: "Menlo, Monaco, Consolas, Liberation Mono, Courier New, monospace"
    fontSize: "0.75rem"
    fontWeight: 400
rounded:
  sm: "4px"
  md: "6px"
  lg: "8px"
  full: "9999px"
spacing:
  "72": "18rem"
  "84": "21rem"
  "96": "24rem"
components:
  button-icon:
    backgroundColor: "{colors.panel-light}"
    textColor: "{colors.muted-light}"
    rounded: "{rounded.md}"
    height: "36px"
    padding: "0 10px"
  badge-status:
    backgroundColor: "#ede9fe"
    textColor: "#6d28d9"
    rounded: "{rounded.full}"
    height: "36px"
    padding: "0 10px"
  chip-queue:
    backgroundColor: "#f3f4f6"
    textColor: "{colors.muted-light}"
    rounded: "{rounded.md}"
    padding: "6px 8px"
  input-field:
    backgroundColor: "{colors.panel-light}"
    textColor: "{colors.ink-light}"
    typography: "{typography.mono}"
    rounded: "{rounded.md}"
  nav-link-active:
    backgroundColor: "#f9fafb"
    textColor: "#030712"
    rounded: "{rounded.md}"
    padding: "8px 12px"
---

# Design System: Oban Web

## Overview

**Creative North Star: "The Control Room"**

Oban Web is a calm operations center. The room itself — canvas, panels, chrome, controls — is rendered in composed neutral grays so that the only things glowing are the signals: eight luminous job-state colors pulsing through charts, sparklines, badges, and counts in real time. The aesthetic is legible but luminous: legibility is the discipline (compact rows, tabular numerals, hairline dividers, labels in quiet caps), and luminosity is the reward (vibrant 400-level state hues that read instantly against the neutral field, especially in the charts). Nothing decorative competes with the data, because the data, live and moving, is the decoration.

The system is built for the 2 a.m. incident as much as the ambient glance: an engineer must be able to find a failing job, read its state by color alone, and act — from either a bright room or a dark one, since every surface ships in full light/dark parity. Interface chrome stays quiet until touched: controls rest as gray glyphs and reveal their label, color, and intent on hover.

**Key Characteristics:**
- Neutral gray architecture; color is reserved for job state and intent
- Eight-hue state palette at Tailwind's 400 level — the signature of the product
- Structural shadows: content floats as panels above a recessed canvas
- Dense, tabular, realtime data display with slashed-zero numerals
- Quiet-until-touched controls that expand and colorize on hover
- Complete dark/light theme parity via the `.dark` class

## Colors

A disciplined neutral gray field carrying eight luminous state hues, one interaction accent, and one brand accent.

### Primary
- **State palette** — the signature system. Each job state owns a Tailwind hue, always at the 400 level (defined in `lib/oban/web/colors.ex`, mirrored in `assets/js/lib/colors.js`):
  - **available** → blue (#60a5fa): ready and waiting
  - **executing** → emerald (#34d399): actively running
  - **completed** → cyan (#22d3ee): finished successfully; also the sparkline bar color
  - **scheduled** → indigo (#818cf8): queued for the future
  - **retryable** → yellow (#facc15): failed, will retry
  - **cancelled** → violet (#a78bfa): stopped deliberately
  - **discarded** → rose (#fb7185): failed permanently
  - **suspended** → gray (#9ca3af): paused; also the fallback for unknown states

### Secondary
- **Interaction blue** (blue-500, #3b82f6): selection and focus — checked checkboxes, focus rings, selected dropdown options, hover on primary actions.
- **Brand violet** (violet-500, #8b5cf6): brand presence inside the tool — sidebar hover affordances, the resize handle, status badges (violet-100/violet-700 pill), the loading spinner fill, active filter row borders.
- **Danger red** (red-500, #ef4444): destructive actions only (delete, cancel), on text and hover borders.
- **Warning amber** (amber-500 #f59e0b light / amber-400 #fbbf24 dark): advisory signal — something is stored but inert, misconfigured, or shadowed, without being an error. Appears as warning flashes and banners (amber-50 / amber-900/20 fills with amber-800 / amber-300 text) and as `text-amber-500 dark:text-amber-400` icons. Advisory only; never for job state, interaction, or destruction.

### Neutral
- **Canvas** (gray-200 #e5e7eb light / gray-950 #030712 dark): the recessed page background everything floats above.
- **Panel** (white #ffffff light / gray-900 #111827 dark): the primary content surface for tables, details, and charts.
- **Ink** (gray-900 #111827 light / gray-100 #f3f4f6 dark): primary text.
- **Muted** (gray-600 #4b5563 light / gray-400 #9ca3af dark): secondary text, resting control glyphs, counts.
- **Faint** (gray-400 light / gray-500 dark): disabled states, placeholder text, column headers.
- **Border** (gray-200 #e5e7eb light / gray-700 #374151 dark): panel-level borders; row dividers step one shade fainter (gray-100 / gray-800).
- **Well** (gray-100 light / gray-950 dark): inset chips and hover fills within panels.

### Named Rules
**The 400 Rule.** State color appears at the 400 level for the hue itself — borders (`border-{hue}-400`), tinted fills (`bg-{hue}-400/10`), chart strokes and sparkline bars. Text shifts to the 600 level in light mode and back to 400 in dark mode for contrast. Never render state color at other weights.

**The Two Accents Rule.** Blue means interaction (selection, focus, checked); violet means brand (sidebar, badges, spinner). They are never interchangeable, and neither is ever used to represent a job state's meaning outside the state palette.

**The Quiet Room Rule.** Chrome is gray. If something on screen is colorful, it is either live job-state data or a hover revealing intent. Color used decoratively is a defect.

## Typography

**Body Font:** Inter var (self-hosted variable woff2, weights 100–900; sans-serif fallback)
**Mono Font:** Menlo (with Monaco, Consolas, Liberation Mono, Courier New fallbacks)

**Character:** A single quiet grotesque doing all the talking, with a system mono stack for machine-truth content — job args, worker payloads, form input. No display face; hierarchy comes from weight, size, case, and color, never from a second personality.

### Hierarchy
- **Headline** (600, 1rem): panel titles ("Jobs", "Queues") and section headings inside detail views.
- **Body** (400–500, 0.875rem): the workhorse — rows, controls, labels, values. Worker names step up to 600 within rows.
- **Label** (500, 0.75rem, 0.05em tracking, uppercase): table column headers and sidebar section headers. The quiet-caps voice of the chrome.
- **Mono** (400, 0.75rem): job args, tags, and metadata inline; form fields use the mono stack at 0.875rem.

### Named Rules
**The Tabular Rule.** Every numeral — counts, timestamps, durations, attempts — uses the `.tabular` utility (`font-variant-numeric: slashed-zero tabular-nums`). Live numbers must not jitter as they tick.

**The One Voice Rule.** Inter var is the only display voice. Mono appears exactly where content is machine truth (args, JSON, identifiers), never for emphasis.

## Layout

A full-viewport control room: `main` wraps everything in 16px padding (`p-4`) with a flex column of header, content, footer. The header aligns the logo to the sidebar column (21rem at `md:`), followed by text-only nav links and a right-aligned cluster of utility controls (shortcuts, connectivity, theme, refresh, help, instances).

Pages are a two-column flex: a **resizable sidebar** (default 320px, drag-persisted to localStorage via `--sidebar-width`, applied pre-paint to avoid flash) holding collapsible filter sections, and a flex-grow **content panel**. Custom spacing steps 72/84/96 (18/21/24rem) exist for sidebar-scale widths.

The system is **desktop-first by commitment, not omission**: this is a tool used at a desk on full-size screens, and mobile/tablet are not optimization targets. The `md:` breakpoint exists only as a graceful fallback for narrow windows (columns stack, some controls hide) — never design toward it, and never trade desktop density or clarity for small-screen coverage.

Density is high and consistent: rows are compact (~10px vertical padding) and separated by hairline dividers (`divide-y` in gray-100 light / gray-800 dark) rather than boxes. Column headers sit under a single stronger border (gray-200 / gray-700). Empty states center a glyph and one sentence in the panel body. Vertical rhythm follows Tailwind's 4px grid throughout.

## Elevation & Depth

Shadows are **structural**: they define the surface hierarchy of the room rather than decorate it. The canvas sits recessed; content panels float one level above it; transient surfaces (menus, popovers, toasts) float above panels. Tonal stepping (gray-200 → white in light, gray-950 → gray-900 in dark) reinforces the same hierarchy so depth survives in dark mode where shadows fade.

### Shadow Vocabulary
- **Panel** (`shadow-lg` on `rounded-md` surfaces): the primary content panels — jobs table, queues table, detail views.
- **Popover** (`shadow-lg` + `ring-1 ring-black/5`): dropdown menus, search suggestions, flash toasts; the hairline ring keeps edges crisp on light backgrounds.
- **Overlay hint** (`shadow-md`): tooltips (Tippy) and floating chart legends.
- **Well** (`shadow-inner` + `ring-1 ring-inset` gray-300/gray-700): the search input — the one recessed surface, signaling "type into me."

### Named Rules
**The Floating Panel Rule.** There is exactly one panel elevation. Panels never stack shadows on shadows; anything above a panel is transient (menu, tooltip, toast) and gets the popover treatment.

## Shapes

Soft-rectangle geometry, tuned small. The default corner is gently rounded (`rounded-md`, 6px) — panels, buttons, chips, inputs, menus all share it. Tight corners (4px) appear on the smallest controls: checkboxes and tooltips. Toasts round slightly more (8px). Full pills (`rounded-full`) are reserved for status badges and the sidebar resize grip. Borders are hairline (1px) everywhere; no heavy outlines, no hard-cornered rectangles, no oversized radii. The one non-rectangular signature is the faceted polygonal Oban gem logo.

## Components

### Buttons
- **Icon buttons** (bulk actions: retry, cancel, delete): 36px tall, `rounded-md`, hairline border, white/gray-800 fill. Rest state is a gray glyph; hover expands a hidden label (`max-w-0 → max-w-24`, 200ms) and colorizes the glyph and border toward intent — blue for act, yellow for pause, red for destroy, violet for edit. Disabled drops to faint gray on a gray fill with `cursor-not-allowed`.
- **Action buttons** (row-level text actions): borderless, gray-500 text with an icon, `hover:bg-gray-100 dark:hover:bg-gray-950`; danger variant uses red-500 text.
- **Load more/less**: bare text buttons, 600 weight, underlined by a border-bottom that darkens on hover; inactive drops to faint gray.

### Chips
- **Queue chips**: mono-adjacent tabular text at 0.75rem in a `rounded-md` well (gray-100 light / gray-950 dark), padding 6px 8px. Informational, not interactive.
- **Filter chips** (in the search bar): removable tokens rendered inline within the search well.

### Cards / Containers
- **Corner Style:** `rounded-md` (6px)
- **Background:** white light / gray-900 dark
- **Shadow Strategy:** Panel level (`shadow-lg`); see Elevation
- **Border:** none on panels — the shadow and tonal step carry the edge
- **Internal Padding:** compact; headers ~12px vertical, rows ~10px

### Inputs / Fields
- **Style:** mono text at 0.875rem, white/gray-800 fill, hairline gray-300/gray-600 border, `rounded-md`, subtle `shadow-sm`
- **Focus:** blue-500 ring and border (`focus:ring-blue-500 focus:border-blue-500`)
- **Disabled:** 50% opacity
- **Checkboxes:** custom 16px squares, 4px radius; checked fills blue-500 with a white check; indeterminate shows a dash; group-hover pre-fills gray

### Navigation
- Text-only links (600 weight, 0.875rem, `rounded-md`, 8px 12px padding). Active page gets a subtle fill (gray-50 light / gray-800 dark) and full-strength ink; inactive stays muted and sharpens on hover. No underlines, no icons.

### Search Bar (signature)
The command surface of the control room: a recessed well (`shadow-inner`, inset ring) containing a magnifying-glass glyph that swaps to a violet-filled spinner while loading, inline filter chips, and a borderless transparent input. Suggestions drop in a popover panel with name/description/example rows.

### Sidebar Filter Rows (signature)
Each row is a link with a 4px transparent left border: active rows snap the border to violet-500 and bolden; hover previews violet-400. Counts sit right-aligned in tabular muted text. Sections collapse via a rotating chevron with a `fade-in-scale` transition. The sidebar's right edge carries a grab handle — a gray pill that glows violet on hover — for drag-resizing.

### Status Badges
Violet pill (violet-100 fill / violet-700 text light; violet-700/70 fill / violet-200 text dark), 36px tall, icon-first, expanding a label on hover exactly like icon buttons. Used for connectivity, access, and instance status in the header.

### Sparklines & Charts (signature)
Inline SVG sparklines: cyan (#22d3ee) 4px bars with 1px gaps and 1px radius over gray-200/gray-700 placeholder stubs, tooltip on hover. Full charts (Chart.js) stroke series in the state palette's 400-level hexes — this is where the luminous half of the identity earns its keep.

## Do's and Don'ts

### Do:
- **Do** color job state exclusively through the state palette: `border-{hue}-400`, `bg-{hue}-400/10`, `text-{hue}-600 dark:text-{hue}-400`.
- **Do** pair every light-mode class with its dark twin in the same edit; both themes ship together or not at all.
- **Do** use `.tabular` on any number that updates live.
- **Do** keep controls quiet until touched — gray at rest, label + color on hover, 200ms transitions.
- **Do** keep all assets self-contained: the Inter woff2 ships in the package; icons are inline SVG via the icon plugin; no CDN references.
- **Do** carry CSP nonces (`@csp_nonces`) on any inline style or script.

### Don't:
- **Don't** introduce a second font family, a display face, or green-on-black terminal styling — the developer audience is served by clarity, not costume.
- **Don't** add KPI stat tiles, gradient cards, or dashboard-cliché decoration; charts and counts already carry the signal.
- **Don't** add mascots, confetti, oversized radii, or marketing gloss inside the tool; persuasion lives on oban.pro, not in the control room.
- **Don't** use violet for interaction states or blue for brand moments (The Two Accents Rule).
- **Don't** put borders and shadows on the same panel, or stack panel shadows inside panels.
- **Don't** ship heavy JS or per-frame re-renders; every surface must stay light under continuous LiveView updates.
- **Don't** optimize for mobile or tablet; desktop is the operating environment, and small-screen behavior is a fallback, not a design target.
