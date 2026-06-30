# Tuner Issues — Summary for Expert Review

## The Core Problem

FretShed's tuner uses AccelerateYIN (FFT-based YIN pitch detection) running at ~86 Hz update rate through AVAudioEngine. When a guitar string is plucked and allowed to decay naturally, the tuner displays significant flat-ward pitch drift — typically 12–35 cents — even on strings verified as in-tune using a PolyTune hardware tuner. This makes the tuner unusable for accurate tuning because:

1. Users see the pitch dropping during note decay and compensate by tuning sharp
2. When returning to a previously tuned string, it appears out of tune due to inconsistent readings between plucks
3. Fine-tuning with small peg adjustments is difficult because the display behavior is unpredictable
4. Floyd Rose / floating tremolo bridges (where all strings are interdependent) would be impossible to balance

**Testing environment:** iPhone 16 Pro, USB audio interface, clean electric guitar signal (no amp, no effects). Room noise is not a factor.

---

## Root Cause Analysis

### Why YIN drifts flat during decay

As a guitar note decays, the signal-to-noise ratio drops. YIN's autocorrelation function becomes increasingly noisy, and the cumulative mean normalized difference (CMND) minimum shifts toward longer lag values (lower frequencies). This produces a systematic flat-ward bias of approximately 0.10–0.20 cents per frame (~86 frames/second), accumulating to 12–35 cents over a 2–3 second decay depending on the string.

Key observations from device testing (all strings verified in-tune with PolyTune first):
- Low E string: drifts from +13¢ to -10¢ (23¢ range)
- A string: drifts from -2¢ to -22¢ (20¢ range)
- D string: drifts from -2¢ to -35¢ (33¢ range, worst offender)
- G string: drifts from -0.5¢ to -16¢ (15.5¢ range)
- B string: drifts from -1.9¢ to -14¢ (12.1¢ range)
- High E string: drifts from +10¢ to -23¢ (33¢ range)

### Why the tuner fast path made it worse

In Phase 2 of the tuner rewrite, we created a "tuner fast path" in the tap closure that skipped several DSP quality checks to reduce latency:
- Spectral subtraction noise capture during silence was disabled (`if !sustainEnabled`)
- Spectral flatness gate was skipped entirely
- Crest factor and harmonic regularity checks were skipped

Without the spectral flatness gate, degraded decay-phase frames (where the signal has become noise-like) were passed through as valid pitch detections with increasingly flat readings.

### Additional factors

- **Attack transient sharp bias:** Guitar pluck attack has sharp inharmonic partials that decay faster than the fundamental, causing initial sharp readings that settle over ~50–100ms
- **USB interface compounds the problem:** High SNR means the signal stays above the noise gate for much longer than built-in mic, so degraded readings persist for seconds instead of being cut off
- **Guitar string physics:** Strings do genuinely go slightly flat during decay due to nonlinear tension effects, but this is 1–3 cents, not 12–35 cents

---

## What We Changed (Tuner Rewrite Phases 1–2.5)

### Phase 1 — Quick Wins (T.P1) ✅
- I/O buffer reduced from 93ms to 5ms in sustain mode
- Sub-cent display precision (`%+.1f ¢`)
- SHARP/FLAT directional labels
- Consecutive frame gate reduced to 2 (tuner) vs 3 (quiz)
- HPF lowered to 50 Hz, maxTau extended for Drop C/D support
- Bluetooth latency warning banner

### Phase 2 — Core Architecture (T.P2) ✅
- **TunerDisplayEngine.swift** (new file): Gain-scheduled second-order spring-damper replacing EMA + SwiftUI `.spring()` animation. Three zones: coarse (300/35), fine (200/30), precision (80/22). Input EMA (alpha=0.4) smooths pitch detection jitter. Transient suppression (3 frames) on note change. Not `@Observable` — plain class read by `TimelineView` to avoid "setting value during update" crashes.
- **Tracking mode:** Two-state consumer (acquiring → tracking). Once a note is established via consecutive gate, tracking mode skips the gate for faster response. Attack stabilization skips first 4 frames (~46ms) to let pluck transient pass.
- **Cents-space median filter:** 13-frame sliding window median operates in cents (not Hz) for uniform smoothing across octaves.
- **Tuner fast path:** Tap closure skips spectral subtraction, crest factor, harmonic regularity, and tonal signal gate in sustain mode. (This was later partially reverted — see Phase 2.5.)
- **Confidence hysteresis:** Once tracking, accepts confidence >= 0.55 (vs 0.85 threshold) to extend sustain. Tracking exits after 600ms of low confidence or 2 consecutive frames of different note.
- **Hold duration:** 1.5 seconds in sustain mode to bridge gaps during note decay.

### Phase 2.5 — Pitch Drift Fix Attempts (T.P2.5) 🚧

#### Attempt 1: Re-enable spectral flatness gate
**What:** Restored the spectral flatness check in the tuner fast path and re-enabled noise spectrum capture during silence.
**Result:** Didn't help enough. The decaying guitar signal is still tonal (harmonics present), so it passes the flatness gate. The drift is from YIN itself, not from noise being misidentified as signal.

#### Attempt 2: Hard decay freeze
**What:** Track peak amplitude during tracking. When signal drops ~12 dB from peak, freeze the displayed cents value completely.
**Result:** User reported this makes fine-tuning impossible — "most players do not tune right as they pluck, they let the note decay and tend to fine tune right at the time this tuner ends up freezing the needle." Users need to see peg adjustments reflected during the decay phase.

#### Attempt 3: DecayStabilizer with spike-based breakout
**What:** Extracted a `DecayStabilizer` struct with:
- Dual lock triggers: amplitude drop (~5 dB) OR time-based (~230ms / 20 frames)
- Lock captures current median as reference value
- Spike detection on raw cents (pre-median) for peg turn breakout — frame-to-frame delta > 0.5¢ triggers breakout in 1 frame
- After breakout, updates lock point and continues monitoring
- 17 unit tests covering drift suppression, peg turn breakout, USB/mic scenarios

**Result:** Multiple problems:
1. **Inconsistent readings between plucks** — the locked value depends on exactly when the lock triggers relative to the attack transient. Different pluck strengths → different peak levels → different lock timing → different locked values.
2. **False spike triggers** — with `spikeFrames=1` and `spikeThreshold=0.5`, normal YIN frame-to-frame variance could exceed 0.5¢ and trigger false breakouts.
3. **Non-linear peg response** — spike triggers, locks at new value, then more spikes cascade as the reading continues to change, creating jerky/unpredictable needle movement.
4. **Parameter sensitivity** — the behavior changed significantly with small parameter adjustments, and optimal values for USB interface were wrong for built-in mic.

#### Attempt 4: Adaptive EMA (current state)
**What:** Removed DecayStabilizer integration. Replaced with 3 lines of adaptive EMA in the tracking loop:
```swift
let error = abs(medianCents - smoothedCents)
let alpha = error > 2.0 ? 0.3 : 0.05
smoothedCents = alpha * medianCents + (1.0 - alpha) * smoothedCents
```
- Heavy smoothing (alpha=0.05) during steady state → drift of 0.15¢/frame becomes ~0.008¢/frame effective
- Fast response (alpha=0.3) when change exceeds 2¢ → peg turns respond in ~250ms
- No locking, no spike detection, no amplitude tracking

**Result:** Not yet tested on device as of this writing. Theoretical analysis:
- Drift suppression: ~1.5¢ total over 200 frames (vs 30¢ raw). Good.
- Peg turn response: ~250ms for large changes (>2¢). Acceptable.
- Small peg adjustments (<2¢): response time ~0.6–1.0 seconds due to slow alpha. May be too slow for fine tuning.
- Consistent between plucks: should be better since there's no lock moment. But attack transient variation could still cause ±2–3¢ variation.

---

## Current Architecture

### Signal Processing Chain (tap closure)
```
HPF (50Hz) → Adaptive Noise Gate → AGC → Low-Shelf Emphasis →
Spectral Subtraction (noise capture re-enabled in sustain mode) →
Spectral Flatness Gate (restored in tuner path) →
AccelerateYIN + HPS Verification →
Tap Confidence Floor (sustain: 0.51, quiz: 0.85)
```

### Consumer Pipeline (main actor async stream)
```
DetectedPitch stream → Confidence Hysteresis →
Tracking Mode State Machine (acquiring → tracking) →
Attack Stabilization (4 frames) →
13-frame Median Filter (cents-space) →
Adaptive EMA (alpha 0.05/0.30) →
Published to @Observable properties →
TunerDisplayEngine (spring-damper) →
TimelineView rendering
```

### Key Files
- `PitchDetector.swift` (~1350 lines) — Core detection + consumer loop
- `TunerDisplayEngine.swift` (~148 lines) — Spring-damper physics for needle animation
- `TunerView.swift` (~580 lines) — SwiftUI view with TimelineView
- `DecayStabilizer.swift` (~100 lines) — Extracted but currently unused (kept for tests)
- `DecayStabilizerTests.swift` (~290 lines) — 17 unit tests for decay scenarios

### Key Parameters (current values)
| Parameter | Value | Location |
|---|---|---|
| Median window | 13 frames | PitchDetector consumer |
| Slow EMA alpha | 0.05 | PitchDetector consumer |
| Fast EMA alpha | 0.30 | PitchDetector consumer |
| Jump threshold | 2.0 cents | PitchDetector consumer |
| Attack stabilization | 4 frames (~46ms) | PitchDetector consumer |
| Confidence threshold | 0.85 | PitchDetector |
| Sustain confidence floor | 0.51 (60% of 0.85) | PitchDetector tap closure |
| Tracking confidence hysteresis | 0.55 | PitchDetector consumer |
| Hold duration | 1.5 seconds | PitchDetector consumer |
| Input EMA alpha | 0.4 | TunerDisplayEngine |
| Spring precision zone | stiffness=80, damping=22 | TunerDisplayEngine |
| Spectral flatness threshold | 0.35 (mic), 0.50 (USB) | AccelerateYIN |
| Hop size | 512 samples (sustain mode) | PitchDetector |
| Window size | 4096 samples | PitchDetector |

---

## User Requirements (from device testing feedback)

1. **Stable readings during note decay** — pluck a tuned string, the display should stay at the correct pitch as the note rings out, not drift flat
2. **Responsive to peg turns** — when turning a tuning peg while the note is still ringing, the display should reflect the pitch change promptly (within ~200–300ms)
3. **Consistent between plucks** — plucking the same string multiple times should show the same reading (within ±1–2 cents)
4. **Needle holds on silence** — when the note fully decays, the needle should stay at the last reading (with opacity fade), not return to center. Returning to center during active tuning causes overshoot when tuning down.
5. **Fine-tuning support** — users pluck, let the note ring, and make small peg adjustments while watching the needle. The tuner must support this workflow, not freeze or cut off during the decay phase.
6. **Works with USB interfaces** — clean signal, high SNR, slow amplitude decay. The tuner must handle this scenario where the signal stays strong for 3+ seconds.

---

## Open Questions

1. **Is the adaptive EMA approach sufficient?** The slow alpha (0.05) may make small peg adjustments (<2¢) too sluggish to see. But increasing alpha lets more drift through.
2. **Should we use a different pitch detection algorithm for the tuner?** YIN's flat-ward bias during decay is a fundamental limitation. Alternatives: autocorrelation with better interpolation, reassigned spectrogram, or hybrid approaches.
3. **Would a strobe-style display hide the drift issue?** Strobe tuners show a moving pattern that stops when in tune — they're inherently less sensitive to small pitch variations. Many professional tuners use strobe for this reason.
4. **Can we weight readings by signal quality?** Instead of binary gate/no-gate, weight each frame's contribution by confidence, amplitude, or spectral clarity. Higher quality frames dominate the average.
5. **Should the median window be larger?** 13 frames gives good outlier rejection but tracks drift closely. 25+ frames would smooth drift more but add ~150ms latency to peg turn response.
6. **Is there a way to detect and compensate for YIN's systematic bias?** If we know the drift is always flat-ward and proportional to signal decay, could we apply a correction factor?
7. **How do professional hardware tuners (PolyTune, Boss TU-3, Peterson StroboClip) handle this?** They likely use different algorithms, dedicated ADC with higher SNR, and/or strobe display to avoid showing instantaneous pitch.
