# Tuner Accuracy Testing Protocol (Task 5.18a)

> **Goal:** Produce documented, reproducible evidence of FretShed's tuner accuracy so the App Store description (Task 5.12) can make a **defensible** accuracy claim (e.g. "sub-5-cent accuracy on every string"). No claim ships without data in the results table below.

---

## Why this matters
FretShed's positioning is "the fretboard trainer that actually gets your notes right." A measured, written accuracy claim is a core differentiator — but only if it's backed by real numbers across guitars and input methods. This protocol is the evidence trail.

---

## Equipment
- **Reference tuner** (ground truth): a hardware strobe/poly tuner — PolyTune, Peterson StroboClip, or Boss TU-3. The reference is assumed correct; FretShed is measured against it.
- **Device:** iPhone running the TestFlight/dev build, with `TunerDiagnosticView` available (`#if DEBUG`, in Settings → Developer).
- **Guitars:** 3–5 instruments spanning types — at minimum 2 electric + 1 acoustic; add classical/nylon if available. Note brand, scale length, string age, and pickup type.
- **Input methods:** (a) built-in iPhone mic, (b) USB/Lightning audio interface. Test both for each guitar where possible.
- **Environment:** quiet room. Record ambient noise condition qualitatively (silent / some HVAC / etc.).

---

## Procedure (per guitar × per input method)

1. **Tune to reference.** Tune all 6 strings with the hardware reference tuner until each reads dead-on (0¢). Do this immediately before each run — strings drift.
2. **Set up FretShed.** Open the app, run audio **calibration** for this guitar + input (or select its saved profile). Then open **TunerDiagnosticView**.
3. **For each test point** in the matrix below:
   - Pluck the string at normal playing strength and **let it ring** — do not damp it.
   - Watch the diagnostic readout. Record the **final settled reading** (the value it holds during the sustain/decay phase, not the attack transient).
   - Repeat the pluck **3 times** and record all three. This captures pluck-to-pluck consistency.
4. **Log** the readings in the results table. Note any string where the reading drifts, sticks, or won't settle.

### Test points (per string)
Test each of the 6 strings at:
- **Open (0)** — fundamental at the lowest, hardest frequency (worst case for MEMS mic on wound strings).
- **5th fret**
- **9th fret**
- **12th fret** — octave; verifies high-frequency tracking and intonation.

> Open + 12th are the priority pair if time is short (they bracket the frequency range and double as an intonation check).

---

## Results Table (one block per guitar × input)

**Guitar:** ____________  **Type:** ___________  **Input:** ___________  **Date:** ___________
**Reference tuner:** ___________  **Calibration profile:** ___________  **Room:** ___________

| String | Fret | Pluck 1 (¢) | Pluck 2 (¢) | Pluck 3 (¢) | Spread (max−min) | Notes |
|---|---|---|---|---|---|---|
| 6 (E) | 0 | | | | | |
| 6 (E) | 12 | | | | | |
| 5 (A) | 0 | | | | | |
| 5 (A) | 12 | | | | | |
| 4 (D) | 0 | | | | | |
| 4 (D) | 12 | | | | | |
| 3 (G) | 0 | | | | | |
| 3 (G) | 12 | | | | | |
| 2 (B) | 0 | | | | | |
| 2 (B) | 12 | | | | | |
| 1 (e) | 0 | | | | | |
| 1 (e) | 12 | | | | | |

*(Add 5th/9th-fret rows when doing the full pass.)*

---

## Pass criteria & claim guidance
- **Per-reading accuracy:** |settled cents − 0| within target on each test point.
- **Consistency:** pluck-to-pluck spread within ±1–2¢ on plain strings.
- **Claim tiers** (use the *worst* result that still holds across all guitars/inputs):
  - All points within **±3¢** → claim "sub-5-cent accuracy" comfortably.
  - Plain strings within ±1–2¢ but low wound strings on **built-in mic** are worse (expected — MEMS roll-off) → claim accuracy **"with an audio interface"** and/or qualify the mic case honestly.
- **Known expectation** (from prior device testing, per CLAUDE.md): USB interface ≈ ±1.5¢ mean across all strings; built-in mic ±1¢ on plain strings, up to ±5¢ on low wound strings.

---

## After testing
1. Fill in the tables and compute spreads.
2. Decide the defensible claim and record the exact wording.
3. Feed that wording into Task 5.12 (App Store description).
4. Archive the completed results (commit this file with data, or store alongside launch assets) as the evidence trail behind the claim.
