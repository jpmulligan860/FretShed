# FretShed — Woodshop Cherry Sunburst Design System Implementation

You are implementing a complete visual redesign of the FretShed iOS app (built in SwiftUI/Xcode). The design direction is called "Woodshop" — a premium, crafted aesthetic inspired by a cherry sunburst Les Paul guitar. The palette was extracted directly from the guitar's finish: cherry red edges, amber/honey center, gold hardware, cream pickguard, and rosewood fretboard.

## IMPORTANT CONTEXT
- This is an existing, working app. Do NOT break any functionality.
- Only change visual/UI elements: colors, fonts, spacing, corner radii, naming, layout.
- The app already has dark mode and light mode support. Update BOTH modes.
- Preserve all existing features and navigation structure, but rename tab labels as specified below.
- Before making changes, read through the existing codebase to understand the current structure, then implement changes systematically file by file.

---

## 1. COLOR SYSTEM

Create/update a centralized color theme file. Use SwiftUI `Color` extensions or an asset catalog. All colors must support both dark and light mode.

### Accent Colors (same in both modes unless noted)
```
cherry:          #C4323C   (primary accent — buttons, active tabs, selected states)
cherryLight:     #D94452   (lighter cherry for hover/pressed states)
amber:           #D4953A   (secondary accent — data highlights, scores, frequencies)
honey:           #E8B84A   (tertiary — golden accents, streaks)
gold:            #C9A84C   (gold hardware — tertiary, used sparingly)
cream:           #E8DCC8   (pickguard cream — used for fretboard nut, light accents)
rosewood:        #3D2B22   (fretboard color — used in fretboard UI)
woodMed:         #8B6F4E   (medium wood tone — muted text alternative)
woodLight:       #B89868   (light wood — subtle accents)
```

### Dark Mode Surfaces
```
background:      #141210   (main app background — warm near-black)
surface:         #1E1B18   (cards, grouped content)
surface2:        #2A2622   (secondary surface — inactive toggles, unselected chips)
border:          #3A3530   (dividers, subtle borders)
text:            #F0E8DE   (primary text — warm off-white)
text2:           #A89880   (secondary text — descriptions, labels)
muted:           #6B5D4D   (muted text — timestamps, captions, tab labels)
```

### Light Mode Surfaces
```
background:      #FAF6F1   (main app background — warm cream-white)
surface:         #F0EBE3   (cards, grouped content)
surface2:        #E8E0D4   (secondary surface)
border:          #DDD4C6   (dividers, card borders)
text:            #2C2218   (primary text — warm near-black)
text2:           #6B5D4D   (secondary text)
muted:           #A89880   (muted text)

Light mode accent variants (slightly darker for contrast on light bg):
cherryLight:     #B02830
amberLight:      #C08530
goldLight:       #B09040
```

### Semantic Colors (both modes)
```
correct:         #4CAF50   (correct answers, mastered state)
correctBg:       rgba(76,175,80,0.12)   (correct answer banner background)
wrong:           #E53935   (wrong answers)
wrongBg:         rgba(229,57,53,0.12)   (wrong answer banner background)
```

### Heatmap Mastery Colors (sunburst gradient progression)
```
untried:         use surface2 (dark) or border (light)
beginner:        #C4323C   (cherry — just started)
developing:      #D4953A   (amber — making progress)
proficient:      #C9A84C   (gold — getting solid)
mastered:        #4CAF50   (green — fully mastered)
```

### Gradient Definitions
```
primaryGradient:     cherry → amber  (linear, 135°) — used for primary CTA buttons
sunburstGradient:    cherry → amber → honey  (linear, 135°) — used for welcome screen branding
progressGradient:    cherry → amber  (linear, 90°, left to right) — progress bars
```

---

## 2. TYPOGRAPHY

Use these three font families throughout the app:

### Montserrat (Primary — install via the app bundle or use system alternative)
- **Display/Hero:** Montserrat Black (900), -1pt tracking
- **Screen titles:** Montserrat ExtraBold (800), 22-28pt
- **Section headers:** Montserrat Bold (700), 15-18pt
- **Body/labels:** Montserrat SemiBold (600) or Medium (500), 12-14pt
- **Small labels:** Montserrat SemiBold (600), 10-11pt

### Crimson Pro (Accent Serif — for italic descriptions and flavor text)
- **Taglines/subtitles:** Crimson Pro Italic, 14-16pt
- **Descriptions:** Crimson Pro Regular, 14-15pt
- Use sparingly — only for: welcome screen subtitle, practice home subtitle ("Time to put in the work."), section descriptions

### JetBrains Mono (Data/Monospace)
- **Data displays:** JetBrains Mono Bold (700), 14-20pt — for BPM, Hz, percentages, scores
- **Small data:** JetBrains Mono Medium (500), 10-12pt — for section labels like "A4 = 440 Hz"
- **Section labels/category headers:** JetBrains Mono SemiBold (600), 9-10pt, ALL CAPS, letter-spacing +1.5pt

If bundling custom fonts is complex, acceptable fallback:
- Montserrat → system rounded (SF Rounded) with matching weights
- Crimson Pro → Georgia italic
- JetBrains Mono → SF Mono or Menlo

---

## 3. TAB BAR — RENAME AND RESTYLE

Rename the 5 tabs as follows (keep the same underlying functionality):

```
OLD NAME        →  NEW NAME    ICON SUGGESTION
Practice        →  Shed        guitar/music.note icon
Progress        →  Journey     chart.line.uptrend or flame icon
Tuner           →  Tuner       tuningfork icon (keep)
MetroDrone      →  Tempo       metronome icon (keep)
Settings        →  Setup       gearshape icon (keep)
```

### Tab bar styling:
- **Active tab:** cherry color (#C4323C dark, #B02830 light) for both icon and label
- **Inactive tabs:** muted color (#6B5D4D dark, #A89880 light)
- **Tab bar background:** surface color with 1px top border using border color
- **Font:** Montserrat SemiBold, 8-9pt, uppercase, +0.5pt letter spacing

---

## 4. COMPONENT STYLES

### Cards
- **Corner radius:** 16px
- **Background:** surface color (dark: #1E1B18, light: #F0EBE3)
- **Border:** light mode only — 1px, border color (#DDD4C6)
- **Padding:** 16px standard, 12px for compact lists
- **No shadows in dark mode.** Subtle warm shadow in light mode: 0 2px 8px rgba(44,34,24,0.06)

### Primary Buttons (CTAs)
- **Background:** primaryGradient (cherry → amber, 135°)
- **Corner radius:** 14px
- **Text:** white, Montserrat ExtraBold, 14-15pt
- **Full width** in most contexts
- **Padding:** 14-16px vertical

### Secondary Buttons / Chips (mode selectors, focus mode options)
- **Selected:** cherry background (#C4323C), white text, Montserrat Bold
- **Unselected dark:** surface2 (#2A2622), text2 color, Montserrat SemiBold
- **Unselected light:** surface (#F0EBE3) with 1px border, text2 color
- **Corner radius:** 10px
- **Padding:** 8px vertical, centered text

### Sliders
- **Track:** surface2 (dark) or border (light)
- **Fill:** primaryGradient (cherry → amber)
- **Thumb:** 16px circle, cherry border (2px), fill = text (dark) or white (light)

### Toggles
- **On:** green (#4CAF50) with white thumb
- **Off:** surface2 (dark) or border (light) with white thumb

### Progress Bars
- **Track:** surface2 (dark) or border (light), 4px tall, 2px radius
- **Fill:** progressGradient (cherry → amber), 2px radius

### Dividers
- **Color:** surface2 (dark: #2A2622) or border (light: #DDD4C6)
- **Height:** 1px

---

## 5. SCREEN-BY-SCREEN IMPLEMENTATION NOTES

### 5a. Welcome / Onboarding (3 pages)
- Page 1: App logo/icon centered, "Welcome to FretShed" with FretShed in sunburstGradient text, subtitle in Crimson Pro italic: "The guitar trainer that actually gets your notes right."
- Page 2: "How it works" — feature list with cherry-colored icons
- Page 3: Microphone permission — cherry/amber gradient mic icon
- All pages: primaryGradient CTA button at bottom
- Page indicators: cherry dot for active, surface2 for inactive

### 5b. Practice Home ("The Shed")
- Title: "The Shed" — Montserrat ExtraBold 22pt
- Subtitle: Crimson Pro Italic — "Time to put in the work."
- Top banner card: gradient background (cherry → amber) with "Do This First" setup prompt (tuner + calibration buttons as frosted white pills)
- Second card: gradient (amber → honey) "Ready to practice?" prompt
- Quick Start section: 2x2 grid of cards, each with a simple icon and 2-line label
- Section headers use JetBrains Mono CAPS style

### 5c. New Session Builder
- Modal-style screen with Cancel / title / empty space header
- Practice Mode: 4-chip row (Relaxed, Timed, Tempo, Streak)
- Session Length: − / count / + layout with cherry-bordered circular buttons
- Focus Mode: 2-column grid of chips (7 options + Chord Progression)
- Prioritize Weak Spots toggle at bottom
- Selected mode description card at bottom
- "Start Practice" primaryGradient CTA

### 5d. Quiz Gameplay
- Top bar: Score, Streak (with 🔥), circular accuracy ring (cherry/amber/green stroke), End button (cherry bg)
- Mode label: "Full Fretboard · Relaxed" in muted, centered
- Note prompt: "Play this note" (JetBrains Mono CAPS), String # (colored), giant note letter (52pt+), fret number
- Fretboard: rosewood-gradient background (#3D2B22 → darker), cream nut, thin string lines, fret wire divisions
- Note dots: green for correct position, red for wrong played note, amber for target
- Progress bar below fretboard
- Feedback banner: correct = green bg/border/text, wrong = red bg/border/text with "X — need Y" format

### 5e. Journey (Progress)
- Title: "Journey" — Montserrat ExtraBold 22pt
- Streak display with 🔥 in amber/honey
- Overall Results card: circular progress ring (amber stroke on surface2 track) with percentage, plus stats list
- Fretboard Mastery heatmap: 6 rows × 13 columns grid, using the sunburst mastery colors
- Legend row below heatmap with small color swatches
- Accuracy Trend chart (keep existing chart but style axes/labels with theme colors)
- Recent Sessions: list of cards with session name, date/duration, and colored percentage (amber for medium, green for high)

### 5f. Tuner
- Full-screen centered layout
- Label: "Chromatic Tuner" in JetBrains Mono CAPS
- Note letter: 64-72pt Montserrat Black in honey/amber color
- Frequency: JetBrains Mono, muted color
- Arc meter: half-circle with surface2 stroke, small green zone at top center, needle in amber, circular amber base with glow shadow
- Cents display: JetBrains Mono Bold, ±value in amber
- Flat/sharp range labels
- "A4 = 440 Hz" at bottom in JetBrains Mono muted

### 5g. Metronome
- Label: "Metronome" JetBrains Mono CAPS centered
- BPM: 64pt Montserrat Black, centered
- BPM slider with gradient fill
- −/Tap/+ button row (surface2 cards with rounded corners)
- Beat indicator dots: active = cherry with glow shadow, inactive = surface2 with border
- Time Signature & Note Division card: chip-row for 1/4, 1/8, Triplet, 1/16
- "Start Metronome" primaryGradient CTA

### 5h. Speed Trainer (below metronome or separate scroll section)
- Start/End BPM with −/+ controls
- Increment and Bars per Step controls
- Stop at End / Loop segmented control
- "Start Trainer" button in amber→gold gradient (to visually differentiate from metronome)

### 5i. Drone
- Key selector: 6×2 grid of note chips (cherry selected, surface2 unselected)
- Octave selector: 3-chip row
- Voicing: 4-chip row (Root, Root+5th, Major, Minor)
- Sound: 3-chip row (Pure, Rich, Piano)
- Volume slider
- "Start Drone" button in amber→gold gradient (differentiate from metronome)

### 5j. Settings ("Setup")
- Title: "Setup" centered
- Grouped card sections: Display, Audio, Audio Setup, Quiz Defaults, Data
- List rows: label left, value/control right, 1px dividers
- Sliders for Detection Confidence, Note Hold Duration, volumes
- Dropdowns shown as amber-colored text with ▾
- "Run Calibration" in cherry as a tappable action
- "Delete All Data" in cherry/red as destructive action at bottom

### 5k. Audio Calibration (modal)
- Cancel / "Audio Calibration" header
- Centered animated icon placeholder
- "Measuring Silence" / "String Test" states
- Detected Input info card with surface2 background
- String test checklist with checkboxes
- "Start Calibration" primaryGradient CTA

---

## 6. GENERAL RULES

1. **Warm tones everywhere.** Never use pure black (#000000) or pure white (#FFFFFF) as backgrounds. The warmth of the palette is what makes this feel like a guitar, not a generic app.
2. **Cherry is king.** It's the primary brand color. Use it for: active tabs, selected chips, primary buttons (via gradient), and interactive highlights.
3. **Amber is the workhorse.** Use it for: data values, percentages, scores, frequencies, dropdown values, and secondary callouts.
4. **Green is ONLY for correct/mastered.** Never use it for UI accents or buttons.
5. **JetBrains Mono CAPS for section labels.** This creates visual hierarchy and a premium feel. Always: 9-10pt, SemiBold, uppercase, +1.5pt letter spacing, muted color.
6. **Gradients are subtle.** The cherry→amber gradient should feel like a natural sunburst, not a neon glow. Use 135° angle for buttons, 90° (left-right) for progress bars.
7. **No pure gray.** All neutral tones should have a warm brown/amber tint. This is the single most important thing that differentiates this design from generic dark mode apps.

---

## 7. IMPLEMENTATION ORDER

Suggested order to minimize conflicts and test as you go:

1. **Color system** — Create/update the centralized color definitions first
2. **Typography** — Add font files and create text style helpers
3. **Tab bar** — Rename labels and apply new active/inactive colors
4. **Common components** — Buttons, cards, sliders, toggles, progress bars
5. **Settings screen** — Low risk, tests all component styles
6. **Tuner** — Self-contained screen, good visual test
7. **Practice Home** — The main landing screen
8. **New Session** — Modal with lots of chip/toggle components
9. **Quiz screens** — Correct and wrong states, fretboard styling
10. **Progress/Journey** — Heatmap colors, charts, session list
11. **Metronome/Speed Trainer/Drone** — Grouped under Tempo tab
12. **Onboarding/Welcome** — Can be done last since users see it once
