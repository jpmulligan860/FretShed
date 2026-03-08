# FretShed Tuner — Expert Review Report

> **Date:** 2026-03-07
> **Purpose:** Comprehensive expert review of the tuner implementation with recommendations for world-class quality.
> **Status:** Planning document — no code changes.

---

## Table of Contents

1. [Harlan Royce — Psychoacoustics & Tuning Perception](#1-harlan-royce--psychoacoustics--tuning-perception)
2. [Nolan Varga — Luthier & Guitar Intonation](#2-nolan-varga--luthier--guitar-intonation)
3. [Wren Okada — Motion Design & Real-Time UI](#3-wren-okada--motion-design--real-time-ui)
4. [Renna Castellano — Core Audio & iOS Latency](#4-renna-castellano--core-audio--ios-latency)
5. [Darren Lowe — DSP Engineering](#5-darren-lowe--dsp-engineering)
6. [Uma Chen — UX Design](#6-uma-chen--ux-design)
7. [Priority Synthesis](#7-priority-synthesis)

---

## 1. Harlan Royce — Psychoacoustics & Tuning Perception

### Current State Assessment

The tuner detects pitch via AccelerateYIN (FFT-based autocorrelation) with HPS cross-checking and reports cents deviation from 12-TET equal temperament. The cents calculation (`PitchDetector.swift:1207–1214`, function `pitchDetectorNoteAndCents`) uses a standard formula:

```
midiFloat = 12.0 * log2(frequency / referenceA) + 69.0
cents = (midiFloat - midiRounded) * 100.0
```

This measures the **fundamental frequency** against theoretical equal temperament. The display range is ±50 cents with integer rounding (`TunerView.swift:264`). Color feedback uses 3 zones: green (≤5¢), amber (≤15¢), red (>15¢) (`DesignSystem.swift:175–180`).

### Gaps & Weaknesses

**G1.1 — No inharmonicity compensation.** This is the most significant psychoacoustic gap. A vibrating string's overtones are slightly sharper than integer multiples of the fundamental due to stiffness (Young's modulus × moment of inertia). The effect is strongest on wound low strings (E2, A2) and negligible on unwound strings (B3, E4). The human ear weights the first several partials when perceiving pitch — not just the fundamental. A guitar tuned so every string reads 0¢ on a fundamental-tracking tuner will sound slightly flat on the low strings because the ear perceives a pitch center weighted toward the (sharp) overtones.

Professional strobe tuners like Peterson compensate for this with "sweetened" tuning offsets — typically +1 to +3 cents on E2, +0.5 to +1.5¢ on A2, and near zero on unwound strings. Without this, FretShed's tuner is measuring correctly but advising tuning that doesn't sound optimal.

**G1.2 — Integer cents rounding loses fine resolution.** The readout at `TunerView.swift:264` rounds to whole cents: `Int(c.rounded())`. For a player doing fine intonation work, the difference between +0.3¢ and +0.8¢ matters. Professional tuners display tenths of a cent (e.g., "+0.3 ¢").

**G1.3 — No guitar-type-aware confidence adaptation.** The confidence threshold is a single value (`confidenceThreshold: Float = 0.85`). Nylon classical strings produce fundamentals with significantly less energy relative to harmonics than steel strings, and the attack transient is softer and slower. Electric guitar through a USB interface has a very different spectral profile from acoustic guitar through the built-in mic. The tuner treats all inputs identically despite these differences.

**G1.4 — Fixed ±50¢ display range doesn't adapt.** When a player is within ±5 cents, they're doing fine tuning. The visual scale is still ±50¢ (the full semicircle), meaning the ±5¢ "in tune" zone is only 10% of the display arc. A professional tuner would zoom in or provide a finer secondary indicator when close to pitch.

### Specific Recommendations

**HR.1 — Sweetened tuning offsets (per-string inharmonicity compensation)**
- What: Add optional per-string cents offsets applied after `pitchDetectorNoteAndCents()`. In tuner mode, when a note is detected, look up its string (based on expected open-string frequency ranges: E2 ~82 Hz, A2 ~110 Hz, etc.) and subtract a compensation offset before displaying cents. Default offsets: E2: +2.0¢, A2: +1.0¢, D3: +0.5¢, G3: +0.3¢, B3: 0¢, E4: 0¢.
- Why: The user tunes so the needle centers, and the result sounds better because it accounts for inharmonicity. This is what Peterson "Sweetened" mode does.
- Complexity: **Moderate.** Needs a string detection heuristic in tuner mode (match detected frequency to nearest open string), a small lookup table, and a user toggle ("Sweetened Tuning" on/off in Settings).
- Dependencies: None. Can be implemented independently. Should be off by default for users who expect raw cents.

**HR.2 — Sub-cent display precision**
- What: Change the cents readout from `Int(c.rounded())` to `String(format: "%.1f", c)` showing one decimal place. Update the `contentTransition` and font if needed.
- Why: Enables fine intonation work. The data already exists at sub-cent precision — we're just rounding it away.
- Complexity: **Trivial.** One line change in TunerView.swift.
- Dependencies: None.

**HR.3 — Adaptive display zoom**
- What: When `abs(cents) < 10`, visually expand the center zone. This could be: (a) a secondary fine cents bar below the needle, (b) a zoom animation on the dial arc, or (c) a numeric display that switches from whole to decimal when close.
- Why: Players overcorrect during fine tuning because they can't see sub-cent movement. Zooming in gives them the resolution to stop tuning when they've nailed it.
- Complexity: **Moderate** for a secondary bar, **Significant** for animated dial zoom.
- Dependencies: HR.2 (sub-cent precision) should come first.

**HR.4 — Guitar-type-aware confidence tuning**
- What: Use the `GuitarType` from the active calibration profile (`CalibrationProfile.guitarTypeRaw`) to adjust confidence thresholds. Classical/nylon: lower to 0.75. Acoustic steel: keep 0.85. Electric: keep 0.85 but widen the tonal gate.
- Why: Nylon strings produce weaker fundamentals and softer attacks. The 0.85 threshold with 3-frame consecutive gate (69ms) can reject valid nylon notes.
- Complexity: **Trivial.** Read guitar type in `applySettings()`, set `confidenceThreshold` accordingly.
- Dependencies: Requires an active calibration profile. Falls back to current behavior without one.

---

## 2. Nolan Varga — Luthier & Guitar Intonation

### Current State Assessment

The tuner currently supports:
- Chromatic detection across the guitar range (E2 82 Hz to ~E5 659 Hz via HPS cap at 1200 Hz, `PitchDetector.swift:685`)
- Sustain mode with confidence hysteresis (0.65 threshold once established, `PitchDetector.swift:312`)
- 500ms hold window to prevent needle dropout during decay (`PitchDetector.swift:255`)
- 60 Hz HPF allowing low E fundamental through (`TapProcessingState:1002`)
- Input-source-aware low-frequency emphasis for built-in mic (`TapProcessingState:1016–1018`)
- Median filter (7-sample window in sustain mode, `PitchDetector.swift:251`)
- Calibration profile pre-seeding of noise floor and input source (`TunerView.swift:193–197`)

### Gaps & Weaknesses

**G2.1 — No dedicated intonation mode.** A luthier's intonation workflow is: (1) tune open string to pitch, (2) play fretted note at 12th fret, (3) compare fretted pitch to the open-string reference (or to the 12th-fret harmonic). The current tuner only shows absolute cents vs. equal temperament — it doesn't compare two readings. The luthier has to remember "open E was +0.3¢" and then mentally compute "12th fret E is +2.1¢, so the difference is +1.8¢ sharp — saddle needs to move back."

**G2.2 — No sharp/flat directional indicator.** The needle position conveys direction, but there's no explicit textual or iconic indicator. When a luthier is under a guitar adjusting a saddle screw, they may not be looking at the screen — they need a glanceable "SHARP" / "FLAT" label or directional arrows.

**G2.3 — Drop tuning and alternate tuning not supported.** The tuner always interprets pitch against standard 12-TET. A player in Drop D (D2 = 73.4 Hz) sees the correct note name, but there's no way to set a target tuning. The 60 Hz HPF gives headroom for Drop D, but Drop C (C2 = 65.4 Hz) would be partially attenuated. Players in Open G, DADGAD, or Nashville tuning have no guidance.

**G2.4 — Dead/old strings produce weaker fundamentals.** Old wound strings lose harmonic content and fundamental strength unevenly. The AGC compensates for overall level, but the spectral balance shift means YIN may lock onto the 2nd partial more often. No diagnostic for "your strings may be dead."

**G2.5 — No capo support.** With a capo at fret 2, the open strings are F#, B, E, A, C#, F#. The tuner shows the correct note names, but a guitarist who isn't music-theory-fluent may be confused. A capo setting that maps "string 6 open = F#" would help.

### Specific Recommendations

**NV.1 — Intonation comparison mode**
- What: Add a toggle or mode in the tuner: "Intonation Check." When active: (1) user plays open string — tuner locks the reference reading (note + exact cents); (2) user plays 12th fret fretted — tuner shows the delta from the reference; (3) display shows "Open: E +0.3¢ → Fretted: E +2.1¢ → Delta: +1.8¢ sharp." Color code: green if delta <±2¢, amber ±2–5¢, red >5¢.
- Why: This is the single most impactful feature for a luthier or any guitarist doing their own setups. No competitor in the fretboard training space offers this.
- Complexity: **Moderate.** Needs a UI state machine (reference → comparison → display), a "lock reference" button, and a delta display. The pitch data already exists.
- Dependencies: HR.2 (sub-cent precision) for meaningful delta display.

**NV.2 — Sharp/flat directional labels**
- What: Add directional arrows (or text "SHARP" / "FLAT") next to the cents readout. Arrow up + "SHARP" when cents > +1, arrow down + "FLAT" when cents < -1, checkmark when |cents| ≤ 1.
- Why: Glanceable feedback during physical adjustments. Every professional hardware tuner has this.
- Complexity: **Trivial.** 10 lines of SwiftUI in TunerView.
- Dependencies: None.

**NV.3 — Alternate tuning presets**
- What: A tuning picker in the tuner: Standard, Drop D, Drop C, Open G, DADGAD, Open D, Half Step Down, Full Step Down, Nashville. Each preset defines expected note per string. Display shows "String 6: D" with a green indicator when the detected note matches.
- Why: Expands tuner utility significantly. Guitar Tuna's most popular feature.
- Complexity: **Moderate.** Data model for tuning presets, UI picker, per-string display. The detection engine doesn't change.
- Dependencies: None for basic implementation. HR.1 (sweetened offsets) would need tuning-specific offset tables.

**NV.4 — Lower the HPF for Drop C and baritone**
- What: Lower the HPF cutoff from 60 Hz to 50 Hz. C2 (65.4 Hz) fundamental would pass cleanly. B1 (61.7 Hz, baritone 7-string low B) would be just above cutoff.
- Why: Drop C is common in metal/rock. The current 60 Hz HPF attenuates C2's fundamental by ~3 dB (Butterworth rolloff). 50 Hz gives clean headroom. The handling noise / rumble the HPF rejects is primarily below 40 Hz.
- Complexity: **Trivial.** Change `let f0 = 60.0` to `50.0` in `TapProcessingState` init.
- Dependencies: None. Quiz uses the same HPF, but the string-aware frequency constraint prevents sub-bass false detections in quiz mode.

**NV.5 — Extend YIN maxTau for lower frequencies**
- What: The current `maxTau = min(Int(sampleRate / 80.0), halfN - 1)` caps detection at ~80 Hz. For C2 (65.4 Hz), tau = 44100/65.4 = 674, and maxTau = 44100/80 = 551 — C2 would be missed entirely. Change to `sampleRate / 60.0` (or `55.0` for safety).
- Why: Without this, Drop C tuning literally cannot be detected.
- Complexity: **Trivial.** One constant change. The window size (4096) supports tau up to 2048, so there's ample room.
- Dependencies: NV.4 (HPF must pass the frequency for YIN to see it).

---

## 3. Wren Okada — Motion Design & Real-Time UI

### Current State Assessment

The tuner's visual pipeline has three smoothing layers:

1. **Signal level: Median filter** (`PitchDetector.swift:321–338`) — 7-sample sliding window on raw frequency in sustain mode. Rejects outliers. New median computed on each frame.

2. **Data level: Raw cents pass-through** (`PitchDetector.swift:364–367`) — In sustain mode, raw median-filtered cents are published directly to `centsDeviation` with no dead zone.

3. **Display level: Adaptive EMA** (`TunerView.swift:142–157`) — 5-tier alpha based on deviation magnitude:
   - |cents| < 1: alpha = 0.95 (near-instant)
   - |cents| < 3: alpha = 0.8
   - |cents| < 8: alpha = 0.5
   - |cents| < 20: alpha = 0.3
   - |cents| ≥ 20: alpha = 0.15

4. **Animation level: Spring** (`TunerView.swift:321`) — `.spring(response: 0.25, dampingFraction: 0.9)` on the needle angle.

The needle is rendered via Canvas (`TunerView.swift:370–387`), which is efficient. The angle maps linearly: `(cents / 50.0) * 90.0` degrees.

The update rate is ~86 Hz (hop size 512 at 44100 Hz), meaning new cents values arrive every ~6ms. The `onChange(of: detector.centsDeviation)` fires on each new value, running the EMA computation. The spring animation then interpolates between the previous and new `displayCents` value.

### Gaps & Weaknesses

**G3.1 — EMA + Spring double-smoothing creates conflicting dynamics.** The EMA in `onChange` produces a smoothed `displayCents` value. The `.spring()` animation then treats each new `displayCents` as a target and animates toward it with its own dynamics. This means:
- When far from pitch: the EMA (alpha=0.15) creates slow-moving targets. The spring catches up quickly (response=0.25). The visual result is smooth but laggy.
- When near pitch: the EMA (alpha=0.95) passes values nearly raw. The spring then adds its own damping. The result is good but the spring's 0.25s response still introduces ~50ms visual lag on top of the ~6ms data lag.
- The spring has a damping of 0.9 (nearly critically damped), which is correct — but the 0.25s response time is fighting the near-instant EMA for fine tuning.

**G3.2 — No visual distinction between "settling" and "in tune."** When the needle is near center and barely moving, the user can't tell if it's converging (still settling) or stable (truly in tune). A glow, color pulse, or "locked" indicator would give definitive feedback.

**G3.3 — The needle sweeps from center on new note.** `TunerView.swift:135–138` sets `displayCents = 0` when a new note appears (nil→some). The spring then animates from 0 to the actual deviation. This creates a misleading visual — the needle starts at "in tune" and sweeps away, when the user expects it to sweep *toward* the note from wherever it was. For note changes (e.g., tuning the next string), the needle should sweep from its last position to the new pitch's deviation.

**G3.4 — The idle/inactive state is abrupt.** When the note drops out, `displayCents` stays at its last value until the hold expires, then snaps to 0 (via the `.none`/`.silent` handlers setting `centsDeviation = 0`). The spring animates this snap, but it's still a jarring "return to center."

**G3.5 — Canvas-based needle doesn't leverage Metal.** The `Needle` view uses a `Canvas` context, which is CPU-rendered. For a simple line, this is fine performance-wise, but it means every cents update triggers a full Canvas redraw. A `Shape` with `.trim()` would use the GPU path and integrate better with SwiftUI's animation system.

### Specific Recommendations

**WO.1 — Replace EMA + Spring with a single Kalman-inspired filter**
- What: Remove the EMA from `onChange` and the `.spring()` from NeedleDisplay. Instead, use a `TimelineView(.animation)` driving a custom interpolation model that combines signal filtering and visual smoothing into one system. The model: `velocity += (targetCents - displayCents) * stiffness * dt; velocity *= damping; displayCents += velocity * dt`. Stiffness and damping are adaptive: high stiffness (fast response) when near center, low stiffness (gentle sweep) when far.
- Why: Eliminates the double-smoothing problem. One physical model controls both noise rejection and visual behavior. The needle behaves like a physical meter with mass.
- Complexity: **Moderate.** Replace ~30 lines of onChange + spring with a TimelineView + model class. Similar to the existing `StrobeAnimator` pattern (`TunerView.swift:431–448`).
- Dependencies: None.

**WO.2 — "In tune" lock indicator**
- What: When |cents| < 1.0 for more than 500ms continuously, show a visual lock state: green glow behind the center zone, pulsing dot at needle pivot, and/or text change from "±0 ¢" to "IN TUNE." Reset lock when deviation exceeds 2.0¢.
- Why: Gives the player definitive "you can stop now" feedback. Every premium hardware tuner (TC Electronic PolyTune, Peterson StroboClip) has a lock indicator.
- Complexity: **Trivial.** Track time-in-zone with a `@State var inTuneSince: Date?`. Conditional glow overlay.
- Dependencies: None.

**WO.3 — Fix the sweep-from-center behavior**
- What: When a new note is detected, don't reset `displayCents = 0`. Instead, let the needle stay where it is and sweep to the new note's actual cents position. Only reset to center when transitioning from no-note to first-note (app launch or long silence).
- Why: The current behavior creates a false "in tune" flash on every new note before sweeping away. This is confusing — the first visual impression is wrong.
- Complexity: **Trivial.** Remove or gate the `displayCents = 0` reset in `onChange(of: detector.detectedNote)`.
- Dependencies: None.

**WO.4 — Smooth return to idle**
- What: When the note drops out, animate `displayCents` toward 0 gradually (e.g., spring to center over 300ms) rather than holding-then-snapping.
- Why: The hold-then-snap creates a visual discontinuity. A gentle return to center is more polished.
- Complexity: **Trivial.** Already handled by the spring animation if we just set `displayCents = 0` directly — but the hold window delays this. Consider starting the return animation immediately when the note drops, with the hold only preventing a *new* note from replacing it.
- Dependencies: None.

**WO.5 — Adaptive dial arc zoom**
- What: When |displayCents| < 10 for more than 200ms, animate the dial arc to represent ±15¢ instead of ±50¢. The angle mapping becomes `(cents / 15.0) * 90.0`. Tick marks relabel to show smaller intervals. Animate the transition over 300ms.
- Why: Gives 3.3× more visual resolution for fine tuning. The player sees millimeter-level needle movement for sub-cent changes.
- Complexity: **Significant.** Requires animating the dial scale, tick labels, and angle mapping simultaneously. The NeedleDisplay, DialTicks, and CentsScale all need to be parameterized by the current range.
- Dependencies: HR.2 (sub-cent precision) to be meaningful.

---

## 4. Renna Castellano — Core Audio & iOS Latency

### Current State Assessment

**Audio session configuration** (`PitchDetector.swift:148–154`):
- Category: `.playAndRecord` with `.measurement` mode
- Options: `.defaultToSpeaker`, `.mixWithOthers`
- Preferred sample rate: 44100 Hz
- Preferred I/O buffer duration: `Double(bufferSize) / 44100.0` = `4096 / 44100` = **92.9ms**

**Total estimated latency (string pluck to needle movement):**

| Stage | Duration | Notes |
|-------|----------|-------|
| Hardware input latency | ~3–6ms | iPhone built-in mic; varies by model |
| I/O buffer fill | ~93ms | 4096 frames at 44100 Hz (the preferred buffer size) |
| Ring buffer accumulation | 0–12ms | 512-sample hop; may need to wait for next hop boundary |
| HPF + AGC + DSP | <1ms | All vectorized Accelerate ops on 4096 samples |
| YIN detection | ~2ms | FFT + CMND + threshold on 4096 window |
| AsyncStream yield + main actor dispatch | ~1–5ms | Stream buffers newest(1), main actor processes next runloop |
| Median filter warmup | 0ms (steady state) | 7-sample window; no additional latency once filled |
| SwiftUI onChange | ~1ms | Property observation + EMA computation |
| Spring animation | ~50–250ms | response=0.25, damping=0.9; time to reach 90% of target |
| **Total (first detection)** | **~150–370ms** | Dominated by buffer fill + animation |
| **Total (steady state)** | **~60–110ms** | Hop-to-display only |

### Gaps & Weaknesses

**G4.1 — I/O buffer duration is far too large for a tuner.** The `setPreferredIOBufferDuration(92.9ms)` means the OS delivers audio in ~4096-sample chunks. The iOS audio system typically negotiates this down (real values are often 256 or 512 frames), but by *requesting* 93ms, we're telling the system we don't care about latency. For tuner mode, we should request the smallest practical buffer.

The actual delivered buffer size may differ — `AVAudioSession.ioBufferDuration` reports the real value. But requesting 4096 frames signals low-priority latency requirements to the audio system.

**G4.2 — `.playAndRecord` category has higher latency than `.record`.** The `.playAndRecord` category enables both input and output paths, which increases the audio graph's latency because the system needs to manage both directions. The comment says `.record` alone caused "an internal engine assertion on the realtime thread" — this may have been a bug in an earlier iOS version, or it may be related to the metronome sharing the audio session. For tuner-only mode (no metronome), `.record` with `.measurement` mode would give lower latency.

**G4.3 — The tap closure processes the full signal chain for every buffer.** HPF, noise gate, AGC, low-shelf boost, crest factor, spectral subtraction, YIN, HPS, harmonic regularity — all computed on every 512-sample hop. For a tuner (where we don't need spectral subtraction, crest factor, harmonic regularity, or the tonal signal gate), a lightweight fast path could skip these steps.

**G4.4 — No latency reporting to the user.** The tuner doesn't display any diagnostic about the actual audio path latency or input hardware. Users with Bluetooth input may experience 100-200ms additional latency and not understand why the tuner feels sluggish.

**G4.5 — `bufferingPolicy: .bufferingNewest(1)` may drop frames.** The AsyncStream (`PitchDetector.swift:222`) uses `.bufferingNewest(1)`, meaning if the consumer (main actor) can't keep up, intermediate detections are dropped. At 86 Hz production rate, this is fine for the main thread at 60fps, but any main thread hitch (e.g., SwiftUI layout pass) could cause a frame drop that temporarily stalls the tuner.

### Specific Recommendations

**RC.1 — Request smaller I/O buffer for tuner mode**
- What: In `start()`, when `sustainMode == true`, request `setPreferredIOBufferDuration(0.005)` (5ms = ~221 frames at 44.1kHz). The system will negotiate to its nearest supported size (typically 256 or 512 frames on modern iPhones). Keep the 93ms request for quiz mode where low latency matters less.
- Why: Reduces input latency from ~93ms to ~6–12ms. The single biggest latency improvement available.
- Complexity: **Trivial.** One conditional line.
- Dependencies: None. The ring buffer accumulates samples regardless of I/O buffer size.

**RC.2 — Lightweight tuner tap fast path**
- What: In `makeTapClosure`, when `sustainEnabled`, skip: spectral subtraction, crest factor computation, harmonic regularity computation, and the three-way tonal signal gate. Only run: HPF → noise gate → AGC → low-shelf → YIN core. The tonal gate is designed for quiz false-positive rejection — the tuner can accept anything that passes the confidence threshold.
- Why: Reduces per-frame DSP cost by ~30-40%. More importantly, it removes the spectral subtraction (which uses the noise spectrum captured during silence — in tuner mode, there may be long periods without silence, causing the noise estimate to go stale).
- Complexity: **Moderate.** Add conditional branches in the tap closure. Must ensure the return types match.
- Dependencies: None. Quiz path unchanged.

**RC.3 — Investigate `.record` category for tuner-only mode**
- What: When the tuner is the only audio consumer (metronome not playing), use `AVAudioSession.Category.record` instead of `.playAndRecord`. Switch back to `.playAndRecord` if the metronome starts.
- Why: `.record` has lower roundtrip latency because it doesn't maintain the output path.
- Complexity: **Moderate.** Requires detecting whether MetroDroneEngine is active and coordinating audio session category changes. Risk of audio glitches during category switches.
- Dependencies: Need to verify the engine assertion mentioned in the code comment is resolved in iOS 17+.

**RC.4 — Bluetooth latency warning**
- What: In `start()`, after `setActive`, check `AVAudioSession.sharedInstance().inputLatency`. If >50ms, show a non-blocking banner in TunerView: "High input latency detected (Bluetooth). For best results, use the built-in mic or a wired connection."
- Why: Prevents user frustration when the tuner feels sluggish on AirPods.
- Complexity: **Trivial.** Read one property, add a conditional banner.
- Dependencies: None.

---

## 5. Darren Lowe — DSP Engineering

### Current State Assessment

The signal chain for tuner mode is:
```
Hardware input → HPF (60 Hz Butterworth) → Adaptive Noise Gate (4× noise floor) →
AGC (target −18 dBFS) → Low-Shelf Emphasis (input-source-aware) →
Spectral Subtraction → Crest Factor + Harmonic Regularity + Flatness Gate →
AccelerateYIN (4096 window, parabolic interpolation) + HPS cross-check →
Tap Floor (0.51) → AsyncStream → Consumer: Median Filter (7-sample) →
Consecutive Frame Gate (3 frames) → Confidence Hysteresis (0.65) →
Hold Window (500ms) → centsDeviation publication
```

AccelerateYIN uses:
- 4096-sample Hann-windowed buffer (93ms at 44.1kHz)
- FFT-based autocorrelation (zero-padded to 8192)
- CMND (cumulative mean normalized difference) with threshold 0.15
- Parabolic interpolation on bestTau
- HPS 3-term product for fundamental verification (75–1200 Hz range)
- Harmonic regularity (fraction of energy at f0 multiples)
- Spectral flatness (geometric/arithmetic mean of power spectrum)

### Gaps & Weaknesses

**G5.1 — 4096-sample window limits frequency resolution at higher pitches.** At 44100 Hz, the minimum detectable frequency difference is `sampleRate / windowSize` = 10.77 Hz per FFT bin. For A4 (440 Hz), tau = 100.2 samples. Parabolic interpolation refines this to sub-sample accuracy, achieving ~0.1 Hz resolution. This is adequate for most cases, but for the highest guitar notes (E5 at 12th fret, 659 Hz, tau ≈ 67), the CMND has fewer samples to work with and parabolic interpolation operates on a coarser curve.

**G5.2 — Hann window is suboptimal for YIN.** Classical YIN (de Cheveigné & Kawahara, 2002) operates on unwindowed signals. The Hann window was added for spectral analysis (flatness, HPS), but applying it to the YIN autocorrelation changes the difference function's shape. The windowed signal has reduced energy at the buffer edges, which biases the CMND toward shorter lags (higher frequencies). This is a subtle effect but may contribute to octave errors on low strings.

**G5.3 — Consecutive frame gate adds latency.** The 3-frame consecutive gate (`PitchDetector.swift:260`) requires ~35ms (3 × ~12ms at 512-hop) of the same note before publishing. For the tuner, where false note changes are less critical than responsiveness, this could be reduced to 2 frames.

**G5.4 — No pitch tracking mode.** Once a note is established, the tuner should "lock" onto it and only update cents deviation — not re-detect the note from scratch each frame. Currently, every frame goes through full note detection, median filtering, and consecutive gating. A tracking mode that holds the note and only refines cents would be faster and more stable.

**G5.5 — Median filter on frequency doesn't optimally serve cents display.** The median filter operates on frequency (`freqHistory`, `PitchDetector.swift:322–338`). Frequency is a nonlinear space — the same Hz difference means different cents at different octaves. Filtering in cents space would give more perceptually uniform smoothing.

### Specific Recommendations

**DL.1 — Dual-mode detection: note acquisition + pitch tracking**
- What: Add a tracking mode to the consumer task. Once a note is established (consecutive gate met), switch to "tracking" state: skip the median filter reset logic and consecutive gate, just refine cents deviation from the incoming frequency. Exit tracking if: (a) the detected note changes for 2+ consecutive frames, or (b) confidence drops below the sustain threshold for >200ms.
- Why: Tracking mode eliminates the 35ms note-acquisition latency for steady-state operation. The needle updates with ~12ms latency (one hop) instead of ~35ms.
- Complexity: **Moderate.** State machine in the consumer task: `.acquiring` → `.tracking` transitions.
- Dependencies: None.

**DL.2 — Reduce consecutive gate to 2 frames in sustain mode**
- What: Change `consecutiveFrameThreshold` from 3 to 2 when `sustainEnabled`.
- Why: Saves 12ms on initial note detection. The median filter already handles outlier rejection.
- Complexity: **Trivial.** `let consecutiveFrameThreshold = sustainEnabled ? 2 : 3`
- Dependencies: None.

**DL.3 — Filter in cents space, not frequency space**
- What: Convert frequency to cents (relative to current reference) before adding to `freqHistory`. Compute median in cents space. Use the median cents directly instead of converting back through `pitchDetectorNoteAndCents`.
- Why: 1 Hz at 82 Hz (low E) = ~21 cents. 1 Hz at 659 Hz (high E at 12th fret) = ~2.6 cents. Filtering in Hz space applies disproportionate smoothing at different octaves.
- Complexity: **Moderate.** Rework the median filter section of the consumer task.
- Dependencies: None.

**DL.4 — Consider running YIN on unwindowed signal**
- What: Run the YIN autocorrelation on the raw (unwindowed) signal, and only apply the Hann window for the spectral analysis (flatness, HPS, spectral subtraction). This requires duplicating the FFT pass — one windowed for spectral features, one unwindowed for autocorrelation.
- Why: Classical YIN doesn't window. The Hann window reduces energy at buffer edges, which can bias period detection. The spectral features (flatness, HPS) genuinely benefit from windowing.
- Complexity: **Significant.** Requires restructuring `detectPitch()` to separate the spectral analysis from the autocorrelation, and adding a second FFT pass. CPU cost increases ~50% for the YIN analysis.
- Dependencies: Benchmark before implementing to verify the accuracy improvement justifies the cost.

**DL.5 — Adaptive YIN threshold**
- What: The fixed 0.15 CMND threshold works well for clean signals but may reject valid detections from noisy or distorted signals. In sustain mode, when a note is already established (tracking state from DL.1), relax the threshold to 0.25 — the tracking context provides confidence that the note hasn't changed.
- Why: Extends sustain tracking further into the decay phase where CMND values rise.
- Complexity: **Moderate.** Requires passing tracking state from the consumer back to the tap, or adding a secondary threshold check in the consumer.
- Dependencies: DL.1 (tracking mode).

---

## 6. Uma Chen — UX Design

### Current State Assessment

The tuner UI (`TunerView.swift`) consists of:
- **Note header** (110pt height): detected note name + frequency in Hz
- **Needle display** (340×170 semicircular dial): amber needle on dark arc, green center zone (12% of arc), tick marks at 10¢ intervals
- **Cents readout**: ±N ¢ in integer with tuning color
- **Cents scale labels**: -50¢ / 0 / +50¢
- **Input level bar**: 3-color (green/yellow/red) horizontal bar
- **Controls**: "A4 = 440 Hz" static label
- **Landscape layout**: note header left, dial + controls right

The design uses Woodshop tokens consistently. The dial, ticks, and needle are all Canvas-rendered.

### Gaps & Weaknesses

**G6.1 — No string indicator.** The tuner shows the note name (e.g., "E") but not which string the player is likely tuning. "E" could be string 6 (E2) or string 1 (E4). Showing "6th String — E" or a string number helps beginners.

**G6.2 — The "A4 = 440 Hz" control is static.** It's just a label — not interactive. If we support 432 Hz or custom reference (some do want this), there should be a tappable control. If not, it's visual clutter.

**G6.3 — No tuning guidance for beginners.** A beginner doesn't know the order to tune strings or what notes they should be targeting. Guitar Tuna shows a guitar headstock with pegs, guiding string-by-string tuning. FretShed shows nothing — just raw chromatic detection.

**G6.4 — The input level bar is utilitarian.** It serves a diagnostic purpose but doesn't match the premium aesthetic of dedicated tuner apps. It's always visible even when audio is flowing fine.

**G6.5 — No landscape optimization for the dial.** In landscape, the dial and note header share a 50/50 split. The dial at 340pt doesn't scale up to use the available horizontal space. On larger iPhones (Pro Max), significant space is wasted.

**G6.6 — The "in tune" zone is visually subtle.** The green arc segment (`DialArc.trim(from: 0.44, to: 0.56)`) is a slightly thicker green line on the dial. It's not prominent enough to be a target for the user's eye while adjusting tuning pegs.

### Specific Recommendations

**UC.1 — String indicator with auto-detection**
- What: Below the note name, show "6th String" / "5th String" / etc. based on the detected frequency's proximity to standard open-string frequencies (E2, A2, D3, G3, B3, E4). Use a simple closest-match algorithm. For ambiguous notes (e.g., B3 could be string 2 open or string 3 fret 4), default to open-string tuning context.
- Why: Bridges the gap between raw note detection and guitar-specific utility. Especially helpful for beginners.
- Complexity: **Trivial.** Lookup table + frequency range matching.
- Dependencies: None.

**UC.2 — Guided tuning mode**
- What: An optional "Tune My Guitar" mode (accessible from the tuner or the Shed tab) that walks through strings 6→1, showing the target note and a big green checkmark when each string is within ±3¢. Progress indicator shows which strings are done.
- Why: Guitar Tuna's killer feature. Beginners need hand-holding. This is also a natural post-calibration flow ("your guitar is calibrated, now tune it").
- Complexity: **Moderate.** State machine (6 steps), per-string target, checkmark UI.
- Dependencies: UC.1 (string detection) for auto-advancing between strings.

**UC.3 — Enhanced "in tune" zone visual**
- What: When |cents| < 5: (a) the green center segment glows (add a second overlapping arc with blur), (b) the background subtly shifts toward green, (c) the amber needle pivot dot pulses. When |cents| < 1: full green glow + "IN TUNE" badge.
- Why: The user's reward for achieving good tuning should be visually satisfying. This is where delight lives.
- Complexity: **Moderate.** Glow via shadow/blur overlay, conditional animations.
- Dependencies: None.

**UC.4 — Responsive dial sizing**
- What: Replace the fixed `frame(width: 340, height: 170)` on the dial with a `GeometryReader`-based approach that scales the dial to fill available width (with a max of ~400pt to prevent comically large dials on iPad). Scale needle length, tick marks, and pivot proportionally.
- Why: The fixed 340pt dial wastes space on larger devices and may be cramped on SE.
- Complexity: **Moderate.** Parameterize all Canvas drawing by a `dialWidth` value from GeometryReader.
- Dependencies: None.

**UC.5 — Collapse input level bar when signal is good**
- What: Auto-hide the input level bar after 3 seconds of good signal (level between 0.1 and 0.9). Show it again if level drops to near-zero or clips. Or move it to a smaller indicator (thin line or dot) that's always visible but less prominent.
- Why: Reduces visual noise. Once the user is playing and the tuner is detecting, the level bar adds no value.
- Complexity: **Trivial.** Conditional opacity with animation.
- Dependencies: None.

---

## 7. Priority Synthesis

### Quick Wins (High Impact, Low Complexity)

| # | Recommendation | Expert | Impact | Files |
|---|---|---|---|---|
| 1 | **HR.2** — Sub-cent display (one decimal) | Harlan | High — enables fine intonation | TunerView.swift |
| 2 | **NV.2** — Sharp/flat directional labels | Nolan | High — glanceable feedback | TunerView.swift |
| 3 | **DL.2** — Reduce consecutive gate to 2 frames | Darren | Medium — 12ms faster detection | PitchDetector.swift |
| 4 | **RC.1** — Request smaller I/O buffer | Renna | High — reduces input latency ~80ms | PitchDetector.swift |
| 5 | **WO.3** — Fix sweep-from-center on new note | Wren | Medium — eliminates false "in tune" flash | TunerView.swift |
| 6 | **UC.1** — String indicator | Uma | High — guitar-specific utility | TunerView.swift |
| 7 | **RC.4** — Bluetooth latency warning | Renna | Low — prevents confusion | TunerView.swift |
| 8 | **NV.4 + NV.5** — Lower HPF + extend maxTau | Nolan | Medium — Drop C support | PitchDetector.swift |
| 9 | **UC.5** — Auto-hide input level bar | Uma | Low — visual polish | TunerView.swift |

### Core Improvements (Transform the Tuner Experience)

| # | Recommendation | Expert(s) | Impact | Complexity |
|---|---|---|---|---|
| 1 | **WO.1** — Replace EMA+Spring with unified physics model | Wren | **Critical** — fixes the fundamental smoothing problem | Moderate |
| 2 | **DL.1** — Dual-mode: note acquisition + pitch tracking | Darren | **Critical** — eliminates re-acquisition latency | Moderate |
| 3 | **NV.1** — Intonation comparison mode | Nolan | **High** — unique differentiator | Moderate |
| 4 | **WO.2 + UC.3** — "In tune" lock indicator + glow | Wren + Uma | **High** — user delight + usability | Moderate |
| 5 | **RC.2** — Lightweight tuner tap fast path | Renna | **Medium** — performance + stale noise issue | Moderate |

### Advanced / Post-Launch

| # | Recommendation | Expert(s) | Notes |
|---|---|---|---|
| 1 | **HR.1** — Sweetened tuning (inharmonicity compensation) | Harlan | Needs per-string offset research + user toggle |
| 2 | **NV.3** — Alternate tuning presets | Nolan | Significant UI + data model work |
| 3 | **UC.2** — Guided string-by-string tuning | Uma | Good onboarding feature but substantial UI |
| 4 | **WO.5** — Adaptive dial arc zoom | Wren | Complex animation work, high visual impact |
| 5 | **DL.4** — Separate windowed/unwindowed FFT | Darren | Needs benchmarking to justify CPU cost |
| 6 | **HR.3** — Adaptive display zoom (fine cents bar) | Harlan | Simpler alternative to WO.5 |
| 7 | **DL.3** — Filter in cents space | Darren | Correctness improvement, subtle impact |
| 8 | **DL.5** — Adaptive YIN threshold in tracking mode | Darren | Depends on DL.1 |
| 9 | **HR.4** — Guitar-type-aware confidence | Harlan | Requires calibration profile |
| 10 | **RC.3** — `.record` category investigation | Renna | Risk of audio session conflicts |

---

## Summary

The current tuner is functional and well-engineered for its original purpose as a utility tab in a fretboard training app. The signal processing chain is sophisticated (YIN + HPS + spectral subtraction + AGC + confidence hysteresis), and the recent improvements (halved hop size, adaptive EMA, calibration pre-seeding) have moved it toward professional grade.

To reach world-class tuner status, the highest-leverage changes are:

1. **Fix the I/O buffer request** (RC.1) — the single biggest latency improvement, trivial to implement
2. **Replace the double-smoothing with a unified physics model** (WO.1) — the core needle behavior issue
3. **Add note acquisition vs. tracking mode** (DL.1) — eliminates re-detection latency
4. **Sub-cent display + sharp/flat labels** (HR.2 + NV.2) — immediate usability improvement
5. **Intonation comparison mode** (NV.1) — the differentiator that no fretboard training competitor offers

These five changes would put FretShed's tuner on par with dedicated tuner apps while offering capabilities (intonation comparison, calibrated detection) that none of them have.
