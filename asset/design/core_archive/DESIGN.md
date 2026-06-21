---
name: Core Archive
colors:
  surface: '#f8f9fa'
  surface-dim: '#d9dadb'
  surface-bright: '#f8f9fa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f4f5'
  surface-container: '#edeeef'
  surface-container-high: '#e7e8e9'
  surface-container-highest: '#e1e3e4'
  on-surface: '#191c1d'
  on-surface-variant: '#424754'
  inverse-surface: '#2e3132'
  inverse-on-surface: '#f0f1f2'
  outline: '#727785'
  outline-variant: '#c2c6d6'
  surface-tint: '#005ac2'
  primary: '#0058be'
  on-primary: '#ffffff'
  primary-container: '#2170e4'
  on-primary-container: '#fefcff'
  inverse-primary: '#adc6ff'
  secondary: '#505f76'
  on-secondary: '#ffffff'
  secondary-container: '#d0e1fb'
  on-secondary-container: '#54647a'
  tertiary: '#006947'
  on-tertiary: '#ffffff'
  tertiary-container: '#00855b'
  on-tertiary-container: '#f5fff6'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d8e2ff'
  primary-fixed-dim: '#adc6ff'
  on-primary-fixed: '#001a42'
  on-primary-fixed-variant: '#004395'
  secondary-fixed: '#d3e4fe'
  secondary-fixed-dim: '#b7c8e1'
  on-secondary-fixed: '#0b1c30'
  on-secondary-fixed-variant: '#38485d'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#f8f9fa'
  on-background: '#191c1d'
  surface-variant: '#e1e3e4'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  title-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
  mono-code:
    fontFamily: jetbrainsMono
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  sidebar_width: 240px
  context_panel_width: 280px
  base_unit: 8px
  gutter: 16px
  margin_lg: 24px
  touch_target_default: 40px
  touch_target_accessible: 50px
---

## Brand & Style
The design system is anchored in the concept of a "Personal Research Studio." It prioritizes a calm, organized atmosphere that facilitates deep focus and long-term knowledge retention. The personality is approachable yet professional, avoiding the frantic energy of typical productivity tools in favor of a steady, reliable environment.

The visual style is **Corporate / Modern** with a lean toward **Minimalism**. It utilizes generous white space, a structured grid, and purposeful typography to reduce cognitive load. The interface should feel like a high-quality physical tool—precise, durable, and intuitive.

## Colors
The color palette is designed to be unobtrusive. The primary calm blue provides a sense of security and utility, while the neutral off-white background reduces eye strain during extended archival sessions.

### Functional States
- **Primary:** Actionable elements, focus states, and primary navigation.
- **Secondary:** Metadata, inactive states, and supportive icons.
- **Success (Green):** Indicates "Clean" or "Synced" status.
- **Warning (Amber):** Indicates "Conflict" or "Local-only" status.
- **Error (Red):** Critical system errors or "Dirty" data states.

### High Contrast Mode
For accessibility and specialized focus, a pure black/white/yellow theme is available. This mode strips all gradients and subtle shadows, relying strictly on value contrast and thick borders for element definition.

## Typography
This design system utilizes **Inter** for its systematic clarity and neutral tone, ensuring that the user's content remains the primary focus.

- **Headlines:** Use tighter letter-spacing and heavier weights to anchor pages.
- **Body:** Set at 16px to optimize for long-form reading in document archives.
- **Labels:** Small caps are used for metadata like "Local-only" or "Synced" to distinguish system information from user content.
- **Monospace:** **JetBrains Mono** is reserved for Markdown editing and technical metadata.

## Layout & Spacing
The layout follows a **Fixed-Fluid-Fixed** 3-pane architecture typical of professional desktop applications.

- **Navigation (Left Sidebar):** 240px. Contains the library hierarchy, tags, and core filters.
- **Workspace (Center):** Fluid. The primary Markdown editor and document viewer.
- **Context (Right Panel):** 280px. Contains metadata, AI insights, and collaboration history.

A strict **8px grid** governs all internal spacing. Components should use 16px padding for standard containers and 24px for major section separations. Interaction targets default to 40px but must scale to 50px when the "Accessibility Mode" toggle is active.

## Elevation & Depth
Depth is communicated through **Tonal Layers** rather than heavy shadows to maintain a clean, "flat-plus" aesthetic.

- **Level 0 (Base):** Soft off-white (#F8F9FA) for the application background.
- **Level 1 (Panels):** Pure white (#FFFFFF) for the Sidebar and Context panels, separated by 1px subtle borders (#E2E8F0).
- **Level 2 (Cards/Modals):** Pure white with an ambient, extra-diffused shadow (0px 4px 12px rgba(0,0,0,0.05)) to indicate interactivity or focus.
- **Level 3 (Popovers):** Higher contrast shadows (0px 8px 24px rgba(0,0,0,0.1)) to separate floating UI from the primary workspace.

## Shapes
The design system uses **Soft** geometry. This provides a modern, friendly feel without sacrificing the professional structure required for an archive tool.

- **Standard Elements:** 0.25rem (4px) for buttons, inputs, and small chips.
- **Containers:** 0.5rem (8px) for cards and main workspace panels.
- **Large Components:** 0.75rem (12px) for modals and primary empty-state illustrations.

## Components

### Buttons & Controls
Buttons use solid fills for primary actions and subtle 1px outlines for secondary actions. In the footer, a clear toggle switch allows users to jump between "Friendly Light" and "High Contrast" modes instantly.

### Status Badges
Status labels are critical for local-first sync transparency. They use a "pill" shape with low-saturation background tints:
- **Synced:** Green tint, green text.
- **Local-only:** Amber tint, amber text.
- **Conflict:** Red tint, red text.
- **Privacy-first:** A special blue badge with a lock icon, used for encrypted archives.

### Markdown Editor
The editor uses a clean, distraction-free interface. Typography scales within the editor follow the main scale, but use a subtle left-margin gutter for line numbers or fold-indicators to maintain the "Research Studio" feel.

### Cards
Archive cards display a document title, a 2-line preview, and the status badge in the bottom-right corner. Cards use a subtle border on hover rather than a shadow change to keep the UI stable and quiet.

### Checkboxes & Radios
Custom-styled controls using the primary blue. Checkboxes use a 4px corner radius to match the overall shape language, while radio buttons are circular for clear affordance.