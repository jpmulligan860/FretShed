# Device Test Checklist — Post Board Review

**Build:** `4bce0d2` (tag: `board-review`)
**Date:** Feb 2026
**What changed:** Design system sweep (458 color/font replacements), QuizLaunchCoordinator extraction, copy improvements, session length hints, notification cleanup

Test in **both dark mode and light mode**. Mark each item: PASS / FAIL / NOTE.

---

## 1. Quiz Launch Flow (Critical)

These paths all changed under the hood with the coordinator extraction.

- [ ] **Hero card → full session:** Shed tab → tap "Ready to practice?" card → Session Setup opens → configure → Start Practice → quiz runs → answer a few → End → "Back to The Shed" → lands on Shed tab
- [ ] **Quick Start: Same Note Full Fretboard** → quiz launches directly, plays correctly
- [ ] **Quick Start: Single String Workout** → quiz launches directly
- [ ] **Quick Start: Random Notes Full Fretboard** → quiz launches directly
- [ ] **Quick Start: Repeat Last** (if previous session exists) → quiz launches with same settings
- [ ] **Session summary → Repeat** → brief pause → new quiz starts with same config
- [ ] **Calibration gate (uncalibrated):** Delete calibration → tap hero card → gate alert appears → "Calibrate Now" → calibration flow → completes → Session Setup opens
- [ ] **Calibration gate → Use Tap Mode:** Gate alert → "Use Tap Mode" → Session Setup opens → Start → quiz runs in tap mode (no mic)
- [ ] **Tap mode restored after quiz:** After tap mode quiz → End → start new session → tap mode is OFF again (not stuck on)

## 2. Tab Navigation

- [ ] All 5 tabs selectable: Shed, Journey, Tuner, Tempo, Setup
- [ ] Tab icons and labels display correctly
- [ ] Active tab is cherry colored, inactive tabs are muted
- [ ] During quiz, tab bar is hidden/non-interactive
- [ ] After quiz ends, tab bar reappears and works normally
- [ ] Progress empty state "Start Practicing" button → switches to Shed tab

## 3. Session Setup Screen

- [ ] Practice mode chips render correctly (Relaxed, Timed, Tempo, Streak)
- [ ] Focus mode chips render correctly (all 7 + Chord Progression)
- [ ] Selected chips are cherry, unselected are surface2/muted
- [ ] **Session length hint** appears below the counter (e.g., "Quick session — great for a warm-up")
- [ ] Hint text changes as you adjust length (10→25→50→51+)
- [ ] Info button → Practice Mode info sheet → colors are cherry/amber/gold (not system blue/purple)
- [ ] Info button → Focus Mode info sheet → colors are Woodshop tokens
- [ ] Info button → Chord Progression info sheet → colors correct
- [ ] "Prioritize Weak Spots" toggle works
- [ ] "Start Practice" gradient button works

## 4. Quiz Gameplay

- [ ] Score, streak, accuracy ring display correctly at top
- [ ] "Play this note:" label (or "Find this note:" in tap mode)
- [ ] Note letter is large and readable
- [ ] String number colored correctly
- [ ] Fretboard: amber target dot, green correct dot, red wrong dot
- [ ] Correct feedback banner: green background, green text
- [ ] Wrong feedback banner: red background, red text
- [ ] Progress bar fills with cherry→amber gradient
- [ ] **"Session saved to Journey"** text appears when session completes (not "Session saved to Progress")
- [ ] End button works → shows session summary

## 5. Session Summary

- [ ] Trophy icon color matches accuracy (honey ≥90%, amber ≥70%, cherry <70%)
- [ ] Stat cards show correct icons and colors (amber flame, green checkmark, cherry list, etc.)
- [ ] Mastery badge color matches mastery level
- [ ] Heatmap renders with correct colors
- [ ] **"Back to The Shed"** button text (not "Done")
- [ ] "Back to The Shed" button works → returns to Shed tab
- [ ] "View Progress" button works → switches to Journey tab
- [ ] "Repeat" button works → launches new quiz

## 6. Progress / Journey Tab

- [ ] Title says "Journey"
- [ ] Heatmap uses sunburst colors (cherry→amber→gold→green)
- [ ] Session list: accuracy percentages colored (green ≥80%, amber ≥60%, red <60%)
- [ ] Mode labels colored (cherry for Full Fretboard, amber for Single Note, etc.)
- [ ] Chart axes and labels use warm theme colors (not cyan/system blue)
- [ ] Cell detail sheet: tap a heatmap cell → sheet opens with correct colors

## 7. Settings / Setup Tab

- [ ] Title says "Setup"
- [ ] **"Detection Sensitivity"** label (not "Detection Confidence")
- [ ] **"Note Hold Time"** label (not "Note Hold Duration")
- [ ] Slider tracks and fills use theme colors
- [ ] Dropdown values in amber
- [ ] "Run Calibration" in cherry
- [ ] "Delete All Data" in red/cherry at bottom
- [ ] Back Up / Restore buttons present and functional

## 8. Tuner

- [ ] Warm background (not pure black/white)
- [ ] Note letter in honey/amber
- [ ] Needle in amber with glow
- [ ] Cents display in amber
- [ ] Frequency in muted color
- [ ] "A4 = 440 Hz" at bottom in muted

## 9. Tempo Tab (Metronome + Drone)

- [ ] BPM display large and readable
- [ ] Beat dots: cherry active with glow, surface2 inactive
- [ ] Slider fill uses gradient
- [ ] Drone key chips: cherry selected, surface2 unselected
- [ ] Start/Stop buttons use correct gradient colors

## 10. Calibration Flow

- [ ] Welcome screen: detected input source displays
- [ ] Silence measurement: progress ring, auto-advances
- [ ] String test: checkmarks appear in green (correct color)
- [ ] Results screen: quality score ring colored correctly (green/amber/red)
- [ ] "Save & Close" works → returns to previous screen

## 11. Onboarding (reset with fresh install or clear UserDefaults)

- [ ] Page 1: "Welcome to FretShed" with gradient text
- [ ] Page 2: Feature list — "Drones keep your ear sharp" (no comma before "keep")
- [ ] Page 2: Feature 4 — "graphs show" (not "graphs shows")
- [ ] Page 3: Mic permission prompt
- [ ] All pages: cherry/amber/gold feature icons (not system orange)
- [ ] Page indicators: cherry active, surface2 inactive

## 12. Dark / Light Mode Toggle

- [ ] Switch mode in iOS Settings → return to app → all screens update
- [ ] No pure black (#000) backgrounds in dark mode (should be warm near-black)
- [ ] No pure white (#FFF) backgrounds in light mode (should be warm cream)
- [ ] Secondary text (text2) legible in both modes
- [ ] Muted text visible but clearly dimmer in both modes
- [ ] Cards have subtle border in light mode, no border in dark mode

---

## Notes / Issues Found

| Screen | Issue | Severity |
|--------|-------|----------|
| | | |
| | | |
| | | |
| | | |
| | | |

---

**After testing:** Report any FAIL items. Fix critical (quiz flow) issues before Phase 4.
