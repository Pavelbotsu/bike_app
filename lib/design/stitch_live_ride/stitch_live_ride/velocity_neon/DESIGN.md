# Design System Strategy: The Kinetic Lens

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Kinetic Lens."** 

Unlike traditional cycling apps that feel like spreadsheets attached to a handlebar, this system is designed to feel like a high-performance heads-up display (HUD). It prioritizes "Glanceable Authority"—the ability for a cyclist moving at 40km/h to instantly digest critical performance data through intentional asymmetry and tonal depth. We break the "template" look by using oversized typography and overlapping glass containers that feel like they are floating over a deep, infinite road.

## 2. Colors & Surface Architecture
This system operates exclusively in a high-contrast dark mode. We do not use "gray"; we use "voids" and "glows."

### The "No-Line" Rule
Sectioning must never be defined by 1px solid strokes. Boundaries are created through:
*   **Tonal Shifts:** Placing a `surface-container-low` (#131313) element against a `surface-container-lowest` (#000000) background.
*   **Luminous Depth:** Using the `secondary` (#00e3fd) or `tertiary` (#8eff71) tokens as ultra-low opacity glows behind containers to define their edges.

### Surface Hierarchy & Nesting
Treat the UI as a series of stacked, frosted acrylic sheets. 
*   **Base:** `surface` (#0e0e0e) or `surface-container-lowest` (#000000).
*   **Primary Containers:** `surface-container` (#191919) for main ride stats.
*   **Floating Elements:** `surface-bright` (#2c2c2c) at 60% opacity with a `backdrop-blur` of 20px.

### The "Glass & Gradient" Rule
To escape the "flat" look, primary actions should utilize a **Signature Texture**: a linear gradient moving from `primary` (#ff8f70) to `primary-container` (#ff7852) at a 135-degree angle. This mimics the light reflecting off a carbon fiber frame.

## 3. Typography: The Performance Scale
We use **Manrope** for its technical, modern geometric qualities and **Inter** for micro-labels to ensure maximum legibility under vibration.

*   **Display (The Metrics):** `display-lg` (3.5rem) is reserved for the single most important metric (e.g., Speed or Heart Rate). It should use a `primary` color token to pop against the dark void.
*   **Headline (The Narrative):** `headline-md` (1.75rem) handles route names and achievement titles. Use `on-surface` (#ffffff) with high tracking (-0.02em) for a premium editorial feel.
*   **Label (The Metadata):** `label-sm` (0.6875rem) in `inter` is used for "BPM," "KM/H," or "WATTS." These should always be uppercase with +0.05em letter spacing to maintain a technical "instrument" aesthetic.

## 4. Elevation & Depth
In "The Kinetic Lens," depth is physical, not digital.

*   **The Layering Principle:** Stack `surface-container-high` (#1f1f1f) on top of `surface-dim` (#0e0e0e) to create a natural "lift."
*   **Ambient Shadows:** For floating HUD elements, use a shadow with a 40px blur, 0px offset, and 6% opacity using the `primary` token color. This creates a "neon underglow" rather than a muddy gray shadow.
*   **The Ghost Border Fallback:** If a container sits on a background of similar value, use a 1px border with `outline-variant` (#484848) set to **15% opacity**. It should feel felt, not seen.
*   **Glassmorphism:** Use `surface-container-highest` at 40% opacity with a heavy background blur for any overlay that appears during a ride (e.g., a paused state or navigation prompt).

## 5. Components

### Buttons (Tactile Triggers)
*   **Primary:** Large `xl` (3rem) rounded corners. Background is the `primary` gradient. Text is `on-primary-fixed` (#000000) for extreme contrast.
*   **Secondary (Glass):** `surface-variant` at 50% opacity with a heavy blur. No border.

### Performance Cards
*   **Constraint:** Absolutely no divider lines. 
*   **Structure:** Use `spacing-6` (2rem) of vertical white space to separate the "Power" section from the "Cadence" section. 
*   **Radius:** Always use `lg` (2rem) or `xl` (3rem) corner radius to mirror the organic curves of cycling frames and tires.

### Data Visualization
*   **Live Graphs:** Use `secondary` (#00e3fd) for elevation and `tertiary` (#8eff71) for cadence. Lines should be 3px thick with a "glow" created by a duplicated 10px blurred line underneath.

### The "Pulse" Chip
*   A specialized component for live heart rate. A `surface-container-highest` pill with a `primary-dim` (#ff734c) dot that uses a subtle scale animation (0.95 to 1.05) to simulate a heartbeat.

## 6. Do’s and Don’ts

### Do:
*   **Do** use asymmetrical layouts. A metric can be pushed to the far left while the label sits at the bottom right of a card to create visual tension.
*   **Do** use `primary-fixed-dim` for inactive states of a toggle—it should look like a dimmed LED, not a dead gray box.
*   **Do** ensure all touch targets are at least `spacing-12` (4rem) in height for use with cycling gloves.

### Don't:
*   **Don't** use 100% white (#ffffff) for large blocks of text. Use `on-surface-variant` (#ababab) for body text to reduce eye strain in dark environments.
*   **Don't** use "Drop Shadows" on cards sitting on the base background. Use tonal elevation instead.
*   **Don't** use standard iOS blue. Every blue must be the neon `secondary` (#00e3fd) to maintain the "Kinetic" brand identity.