# Shed Page Redesign — Implementation Spec

**Status:** Approved — ready for Claude Code
**Date:** March 3, 2026
**Mockups:** shed-redesign-v3.jsx in Claude.ai project (reference only — not all elements ship in v1)

---

## What's Changing

The Shed tab is being redesigned from a stacked-card layout with a modal session builder to a cleaner, faster flow. The goal is fewer taps to playing, less visual clutter, and smarter defaults.

---

## 1. New Shed Page Layout

Replace the current Practice Home ("The Shed") with this structure, top to bottom:

### Header
- Title: "The Shed" — same as current
- Subtitle: Crimson Pro Italic — contextual:
  - New user (no sessions): "Time to put in the work."
  - Returning user: "Pick up where you left off."

### Calibration Banner (conditional)
- Show only if audio calibration has not been completed
- Compact dismissible banner, NOT a card: one line with mic icon, "Audio calibration needed" text, "Set Up" button, dismiss X
- Once calibrated, never shows again

### Primary CTA — "Start Practice" / "Smart Practice"
- Full-width gradient button (cherry → amber), 16px corner radius
- **New users:** Label "START HERE" / "Start Practice" / "Adaptive session based on your level"
- **Returning users:** Label "BASED ON YOUR PROGRESS" / "Smart Practice" / shows which focus mode rotation is next + weak spot count
- One tap → launches adaptive session immediately
- Smart Practice should rotate focus modes across sessions (Full Fretboard → Single String targeting weakest → Same Note drill → cycle). The content within each session is always Bayesian-adaptive; the format varies to prevent monotony.

### Heatmap (returning users only)
- Compact mini heatmap showing the full 6×13 fretboard grid
- Uses existing mastery color system (4-tier: struggling/learning/proficient/mastered)
- String labels on left (e B G D A E)
- Legend row: Weak / Learning / Strong
- For free users: premium cells (strings 1–3 and frets 8+) shown dimmed with subtle hatching. Dashed amber line marks the free/premium boundary.

### Quick Start Presets
- Section header: "QUICK START" in JetBrains Mono caps
- **New users (no history):** 2 preset cards in a row:
  - "Guided Start" — Root note zone, relaxed
  - "Root Notes" — Chord roots within free fretboard area (Note: Natural Notes is premium, so this preset uses Full Fretboard mode constrained to the free area)
- **Returning users:** 3 preset cards in a row:
  - "Weak Spots" — targets lowest-scoring cells
  - "Fill the Gaps" — targets cells with zero attempts
  - "Repeat Last" — shows specific details from last session (focus mode, string, practice mode, accuracy %)
- Presets are dynamic and update based on user history
- All preset cards: min height 100pt, 14px corner radius, surface background with border

### Timed Practice
- Sits below the preset cards as its own component
- Card with timer icon + "Timed Practice" title
- Four time preset buttons: 2 / 5 / 10 / 15 min (default: 5 min selected)
- Small mode picker row: Relaxed (default) / Per-Note Timer / Streak
- "Go — X Minutes" CTA button
- Session runs a countdown, serves adaptive questions until time expires
- Results show: notes correct / notes served, accuracy %, time
- Always free, always adaptive, never gated

### Build Custom Session
- Full-width button: gear icon + "Build Custom Session"
- Opens a **half-sheet** (`.sheet(presentationDetents: [.medium])`) — NOT an inline accordion, NOT a full modal
- Half-sheet contains:
  - Focus Mode chips (all 7 visible): Full Fretboard and Single String are free; Natural Notes, Sharps & Flats, Position, Same Note, Chord Progressions show a small lock icon for free users. Tapping a locked mode triggers the paywall.
  - Practice Mode chips: Relaxed / Timed / Tempo / Streak
  - Session Length: −/count/+ stepper
  - "Start Custom Session" CTA

### What's Removed
- The "Do This First" gradient card — replaced by the compact calibration banner
- The "Ready to practice?" hero card — replaced by the primary CTA
- The old Quick Start 2×2 grid — replaced by dynamic presets
- The full-screen Session Builder modal — replaced by the half-sheet

---

## 2. Onboarding Baseline

Add a new screen to the onboarding flow (after "How it works", before microphone permission) where users self-select their starting fretboard knowledge.

### Screen: "Where are you at?"
- Section label: "GETTING STARTED"
- Title: "Where are you at?"
- Subtitle (Crimson Pro italic): "This helps FretShed focus your practice on what you actually need."

### Five options (single-select, each with icon + title + description):
1. 🌱 **Starting Fresh** — "I'm pretty new — couldn't tell you what note is where"
2. 🎶 **Chord Player** — "I can play songs but couldn't name the notes if you asked me"
3. 🎸 **Open Position** — "I know my way around the first few frets"
4. 🎵 **Low Strings Solid** — "I know the E and A strings — like finding root notes for barre chords"
5. 🔧 **Rusty Everywhere** — "I used to know more of this stuff, but it's been a while"

### Bayesian Prior Seeding
Each selection maps to specific prior values on the 6×13 fretboard grid (78 cells). These priors seed the Bayesian mastery system so the first adaptive session is better than random.

| Selection | Prior Mapping |
|---|---|
| Starting Fresh | All cells: 0.50 (maximum uncertainty) |
| Chord Player | Open strings (fret 0): 0.75; Frets 0–3 on strings 2–5: 0.60; Everything else: 0.50 |
| Open Position | Frets 0–4, all strings: 0.70; Frets 5–12: 0.50 |
| Low Strings Solid | Strings 5–6, all frets: 0.70; Strings 1–4: 0.50 |
| Rusty Everywhere | All cells: 0.55 |

- Priors are seeded for the FULL fretboard (all 78 cells) regardless of free/premium status
- Reassurance text below options: "Don't worry about getting it perfect — FretShed adapts as you play."
- "Continue" button (primary gradient CTA, disabled until selection made)

---

## 3. Freemium Integration

The Shed page must be aware of the user's entitlement status.

### Smart Practice (paywall-aware)
- For free users, Smart Practice constrains question selection to the free fretboard (strings 4–6, frets 0–7)
- The adaptive algorithm works within this constraint but still rotates focus modes

### Heatmap
- Always shows the full 6×13 grid
- Premium cells dimmed with subtle hatching for free users
- Dashed amber line marks the boundary

### Half-Sheet Customizer
- All 7 focus modes visible
- 5 premium modes show lock icon
- Tapping a locked mode triggers the paywall — does NOT hide them

### Timed Practice
- Always free, even if the algorithm sometimes wants to go beyond the free area
- Silently constrains to free fretboard for free users

---

## 4. What Ships Later (NOT in this implementation)

These items came out of the expert review but are post-launch optimizations:

- Calibration progress indicator ("Learning your strengths — 42%")
- Graduation paywall ("Root Note Zone Mastered" milestone prompt)
- "Taste of premium" locked preview questions within quiz sessions
- Tappable heatmap rows/columns as navigation shortcuts
- Micro-diagnostic for "Rusty Everywhere" users
- 70/30 within-session ratio (challenging vs. consolidation)
- Multi-select on baseline options
- Additional dynamic presets from user's frequent configurations
- "What will this session focus on?" tooltip on Smart Practice
- First-heatmap animation after first session completion
