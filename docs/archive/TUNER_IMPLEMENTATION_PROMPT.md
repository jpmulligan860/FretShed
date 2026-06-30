# FretShed Tuner Rewrite — Claude Code Implementation Prompt

> **Instructions:** Paste everything below this line into Claude Code. This is a multi-session project — complete one phase per session, verify, then move to the next. Each phase ends with a verification checklist. Do NOT proceed to the next phase until the current phase passes all checks.

---

## Preamble

Read these files before starting any work:

1. `CLAUDE.md` (full read)
2. `ROADMAP.md` (full read)
3. `TEAM_OF_EXPERTS.md` (full read)
4. `BUGLOG.md` (full read)

Then run `find . -name "*.swift" | sort > FILE_MANIFEST.txt` and identify every file related to the tuner. At minimum, locate and read completely:

- `TunerView.swift`
- `PitchDetector.swift`
- `AccelerateYIN.swift`
- `SignalMeasurement.swift`
- `DesignSystem.swift` (color tokens, typography)
- Any `TunerViewModel`, `TunerState`, or tuner model files
- The tap closure (search for `makeTapClosure` or `installTap`)
- Audio session setup (search for `AVAudioSession`)

Read each file completely before writing any code. You'll need to understand the current architecture to implement the changes correctly.

## Background

This task implements a comprehensive tuner upgrade based on a 9-expert review (6 domain specialists + 3 out-of-the-box engineers from control systems, medical devices, and gaming). The core architectural insight is that the tuner should be restructured into three clean layers:

**Layer 1 — Pitch Engine (truth):** AccelerateYIN produces raw pitch data as fast and accurately as possible. No smoothing at this layer.

**Layer 2 — Display Model (physics):** An interpolation buffer feeds a gain-scheduled second-order spring-damper that produces `displayCents` at the render frame rate. This single physics model replaces BOTH the current EMA filter AND the SwiftUI `.spring()` animation.

**Layer 3 — Visual Presentation (delight):** The needle, settled readout, in-tune state, background wash, string indicator — all visual-only, all driven by the display model's output.

## Critical Constraint

**The quiz path must remain byte-for-byte identical.** All tuner-specific changes must be gated on `sustainMode == true` or `sustainEnabled`. After every phase, run the full test suite and verify all tests pass. If any quiz-related test fails, the change must be reverted.

---

## PHASE 1: Quick Wins

**Goal:** Immediate improvements with zero architectural risk. Each change is independent — implement and verify one at a time.

### 1A. Reduce I/O buffer for tuner mode

**File:** `PitchDetector.swift` — find the `start()` method where `setPreferredIOBufferDuration` is called.

**Change:** Add a conditional based on `sustainMode`:

```swift
// BEFORE (something like):
try session.setPreferredIOBufferDuration(Double(bufferSize) / sampleRate)

// AFTER:
if sustainMode {
    try session.setPreferredIOBufferDuration(0.005) // ~221 frames, system negotiates to 256
} else {
    try session.setPreferredIOBufferDuration(Double(bufferSize) / sampleRate)
}
```

**Leave unchanged:** Everything else in `start()`. The ring buffer accumulates samples regardless of I/O buffer size, so downstream processing is unaffected.

**Why:** Reduces input-to-DSP latency from ~93ms to ~6-12ms. The single biggest latency improvement.

### 1B. Sub-cent display precision

**File:** `TunerView.swift` — find the cents readout where `Int(c.rounded())` or similar integer rounding is used.

**Change:** Replace with `String(format: "%+.1f", c)` to show one decimal place with explicit sign. The `+` prefix gives free sharp/flat indication: "+2.3 ¢" vs "-1.7 ¢".

**Leave unchanged:** The `contentTransition` — verify it still works with the longer string.

### 1C. Sharp/flat directional labels

**File:** `TunerView.swift` — below the cents readout.

**Add:** A directional label using Woodshop design tokens:

```swift
// Below the cents readout
if let c = displayCents {
    if abs(c) <= 1.0 {
        Text("✓ IN TUNE")
            .font(.custom("JetBrainsMono-SemiBold", size: 10))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(DesignSystem.tuningColor(for: c))
    } else if c > 1.0 {
        Text("SHARP ↑")
            .font(.custom("JetBrainsMono-SemiBold", size: 10))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(DesignSystem.tuningColor(for: c))
    } else {
        Text("FLAT ↓")
            .font(.custom("JetBrainsMono-SemiBold", size: 10))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(DesignSystem.tuningColor(for: c))
    }
}
```

Use the existing `DesignSystem.tuningColor(for:)` method (or whatever the current pattern is — check `DesignSystem.swift` for the 3-zone color logic: green ≤5¢, amber ≤15¢, red >15¢).

**Note:** Verify the actual font name in `DesignSystem.swift` — it might be registered as `JetBrainsMono-SemiBold` or accessed through a helper.

### 1D. Reduce consecutive gate to 2 frames in sustain mode

**File:** `PitchDetector.swift` — find where `consecutiveFrameThreshold` is defined or used (around the consumer task).

**Change:**

```swift
// Find the threshold (might be a let constant or hardcoded 3)
let consecutiveFrameThreshold = sustainEnabled ? 2 : 3
```

**Leave unchanged:** The non-sustain (quiz) code path. Quiz must still use 3 frames.

### 1E. Lower HPF and extend maxTau for Drop C/D

**File 1:** `TapProcessingState` (search for where the HPF cutoff frequency is set, likely `let f0 = 60.0` or similar)

**Change:** `60.0` → `50.0`

**File 2:** `AccelerateYIN.swift` — find `detectPitch()` where `maxTau` is computed. Look for something like `min(Int(sampleRate / 80.0), halfN - 1)`.

**Change:** `sampleRate / 80.0` → `sampleRate / 55.0`

**Why both:** The HPF must pass C2 (65.4 Hz) and maxTau must be large enough for YIN to detect the corresponding period (tau = 44100/65.4 = 674). The window size (4096 → halfN = 2048) has ample room.

**Leave unchanged:** The string-aware frequency constraint in quiz mode — it already prevents sub-bass false positives, so this change is safe for quiz.

### 1F. Bluetooth latency warning

**File:** `TunerView.swift` — add a state variable and check after the pitch detector starts.

**Add:**

```swift
@State private var showLatencyWarning = false

// In the .onAppear or .task where PitchDetector is started, after start() completes:
let inputLatency = AVAudioSession.sharedInstance().inputLatency
if inputLatency > 0.05 { // 50ms
    showLatencyWarning = true
}
```

Display as a dismissible banner at the top of TunerView, using Woodshop `surface2` background, `text2` color, Montserrat Medium 12pt:

"High latency input detected. For best accuracy, use the built-in mic or a wired connection."

With a small "✕" dismiss button that sets `showLatencyWarning = false`.

### Phase 1 Verification

After all 1A-1F changes:

- [ ] Run full test suite — ALL tests must pass (including the 3 pre-existing failures which are unrelated)
- [ ] Build and run on simulator — tuner tab loads without crash
- [ ] Verify cents readout shows one decimal place with +/- sign
- [ ] Verify SHARP/FLAT/IN TUNE label appears below cents
- [ ] Verify no visual or behavioral changes on the Quiz tab
- [ ] Log changes to `BUGLOG.md` as a single entry (e.g., `T5 | Tuner Phase 1 quick wins | 6 improvements: I/O buffer, sub-cent display, sharp/flat labels, 2-frame gate, HPF/maxTau, BT warning`)

---

## PHASE 2: Core Architecture — The Three-Layer Rewrite

**Goal:** Replace the EMA + Spring double-smoothing with a clean three-layer architecture. After this phase, the needle behaves like a precision physical instrument.

**Important:** This is the most complex phase. Read all instructions before writing any code. Implement in the sub-step order below.

### 2A. Lightweight tuner tap fast path

**File:** The tap closure function — likely in `PitchDetector.swift` (search for `makeTapClosure` or wherever the `AVAudioNode` tap is installed).

**Change:** When `sustainEnabled` (tuner mode), skip these processing steps:
- Spectral subtraction (adaptive noise spectrum)
- Crest factor computation
- Harmonic regularity computation
- The three-way tonal signal gate (`crestFactor < 2.0 || harmonicReg > 0.3 || flatness < threshold`)

The tuner signal chain becomes:
```
HPF → Noise Gate → AGC → Low-Shelf Emphasis → YIN core + HPS cross-check
```

**Implementation:** Add `if !sustainEnabled { ... }` blocks around the DSP steps being skipped. Do NOT restructure the function — just gate the expensive branches.

**Why:** Removes ~30-40% per-frame DSP cost. Also eliminates the stale noise spectrum problem (spectral subtraction in tuner mode has no guaranteed silence periods to refresh its estimate).

**Leave unchanged:** The entire non-sustain (quiz) code path. Every line of quiz processing must be identical.

### 2B. Note acquisition vs. pitch tracking mode

**File:** `PitchDetector.swift` — the consumer task (the `for await` loop that processes pitch detections from the AsyncStream).

**Add a tracking state enum:**

```swift
private enum TunerTrackingState {
    case acquiring
    case tracking(note: String, octave: Int)
}
```

**Add a state variable** in the consumer task scope:

```swift
var trackingState: TunerTrackingState = .acquiring
```

**Modify the consumer logic** (sustain mode only):

- In `.acquiring` state: current behavior — median filter, consecutive gate, the works. When a note is established (consecutive gate passes), transition to `.tracking(note:octave:)`.
- In `.tracking` state: skip the consecutive gate. Accept the incoming pitch directly and publish the cents deviation. Exit tracking if: (a) detected note name changes for 2+ consecutive frames, OR (b) confidence drops below the sustain confidence threshold (0.65) for >200ms. On exit, transition back to `.acquiring`.

**Leave unchanged:** The entire non-sustain code path. The `trackingState` variable should only be used when `sustainEnabled`.

### 2C. Filter in cents space instead of frequency space

**File:** `PitchDetector.swift` — the median filter section of the consumer task (search for `freqHistory` or the sliding window).

**Change:** Before adding a value to the median filter history, convert frequency to cents deviation from the nearest semitone:

```swift
let midiFloat = 12.0 * log2(freq / referenceA) + 69.0
let centsFromNearest = (midiFloat - midiFloat.rounded()) * 100.0
// Add centsFromNearest to the history instead of freq
```

Then use the median cents value directly for display, rather than converting back through `pitchDetectorNoteAndCents`.

**Why:** 1 Hz at 82 Hz (low E) = ~21 cents. 1 Hz at 659 Hz (high E at 12th fret) = ~2.6 cents. Filtering in Hz space applies wildly disproportionate smoothing across the fretboard.

### 2D. Adaptive YIN threshold in tracking mode

**File:** `AccelerateYIN.swift` — find where the CMND threshold is applied (likely `0.15`).

**Change:** Add a parameter or flag that allows the threshold to be relaxed to `0.25` when in tracking mode. The simplest approach is a `relaxedThreshold` parameter on `detectPitch()`:

```swift
func detectPitch(buffer: [Float], ..., relaxedThreshold: Bool = false) -> DetectedPitch? {
    let cmndThreshold: Float = relaxedThreshold ? 0.25 : 0.15
    // ... use cmndThreshold where the 0.15 was
}
```

In the tap closure, pass `relaxedThreshold: true` when `sustainEnabled` AND a note is currently being tracked (you'll need a way to communicate the tracking state to the tap — either a shared atomic flag or a property on `TapProcessingState`).

**Why:** Extends sustain tracking into the decay phase, especially important for 12th-fret intonation where fretted notes decay faster.

**Leave unchanged:** Quiz always uses `relaxedThreshold: false` (the default).

### 2E. Create TunerDisplayEngine — interpolation buffer + spring-damper

**New file:** `TunerDisplayEngine.swift`

This is the core of the rewrite. Create a new `@Observable` class:

```swift
import Foundation
import Observation

@Observable
final class TunerDisplayEngine {
    // MARK: — Output (read by the view)
    private(set) var displayCents: Double = 0
    private(set) var settledCents: Double? = nil // Phase 3 addition
    
    // MARK: — Internal state
    private var velocity: Double = 0
    private var targetCents: Double = 0
    private var previousSample: (timestamp: CFTimeInterval, cents: Double)?
    private var currentSample: (timestamp: CFTimeInterval, cents: Double)?
    private var suppressionFramesRemaining: Int = 0
    private var lastNoteName: String? = nil
    
    // MARK: — Interpolation buffer
    func pushSample(cents: Double, note: String?) {
        let now = CACurrentMediaTime()
        
        // Transient suppression: if note changed, suppress for 2 frames
        if let note, note != lastNoteName, lastNoteName != nil {
            suppressionFramesRemaining = 2
            lastNoteName = note
            return
        }
        lastNoteName = note
        
        previousSample = currentSample
        currentSample = (timestamp: now, cents: cents)
    }
    
    func pushSilence() {
        // Note dropped — target drifts to zero
        targetCents = 0
        lastNoteName = nil
    }
    
    // MARK: — Per-frame update (called by TimelineView at display refresh rate)
    func update(now: CFTimeInterval) {
        // Handle suppression countdown
        if suppressionFramesRemaining > 0 {
            suppressionFramesRemaining -= 1
            // During suppression, spring-damper continues toward last target (natural deceleration)
        } else {
            // Interpolate between the two most recent samples
            if let prev = previousSample, let curr = currentSample, curr.timestamp > prev.timestamp {
                let t = min(max((now - prev.timestamp) / (curr.timestamp - prev.timestamp), 0), 1.2)
                targetCents = prev.cents + (curr.cents - prev.cents) * t
            } else if let curr = currentSample {
                targetCents = curr.cents
            }
        }
        
        // Second-order spring-damper with gain scheduling
        let dt = 1.0 / 60.0 // Assume 60fps; or compute from delta time
        let error = targetCents - displayCents
        let absError = abs(error)
        
        let (stiffness, damping) = gainSchedule(absError)
        
        let acceleration = stiffness * error - damping * velocity
        velocity += acceleration * dt
        displayCents += velocity * dt
        
        // Clamp to prevent runaway
        displayCents = max(-55, min(55, displayCents))
        velocity = max(-500, min(500, velocity))
    }
    
    private func gainSchedule(_ absError: Double) -> (stiffness: Double, damping: Double) {
        if absError > 15 {
            // Coarse: fast tracking, slightly underdamped (ζ ≈ 0.8)
            return (800, 45)
        } else if absError > 5 {
            // Fine: moderate tracking, critically damped (ζ ≈ 1.0)
            return (400, 40)
        } else {
            // Precision: overdamped — settles without hunting (ζ ≈ 1.4)
            return (150, 35)
        }
    }
    
    func reset() {
        displayCents = 0
        velocity = 0
        targetCents = 0
        previousSample = nil
        currentSample = nil
        suppressionFramesRemaining = 0
        lastNoteName = nil
        settledCents = nil
    }
}
```

**Important:** The gain schedule values (800/45, 400/40, 150/35) are starting points. After implementation, test with a real guitar and tune by feel. The damping values may need adjustment. The goal:

- **Coarse zone:** Needle snaps to the ballpark in <200ms
- **Fine zone:** Needle approaches without overshoot in ~300ms
- **Precision zone:** Needle settles to within 0.3¢ of true value without hunting

### 2F. Rewire TunerView to use TunerDisplayEngine

**File:** `TunerView.swift`

**Remove:**
- The adaptive EMA computation in `onChange(of: detector.centsDeviation)` (the 5-tier alpha block)
- The `@State var displayCents` variable
- The `.spring(response: 0.25, dampingFraction: 0.9)` animation modifier on the needle
- The `displayCents = 0` reset in `onChange(of: detector.detectedNote)`

**Add:**
- A `@State private var displayEngine = TunerDisplayEngine()` (or inject it)
- Wire `PitchDetector.centsDeviation` changes to `displayEngine.pushSample(cents:note:)` via `onChange`
- Wire note-dropout to `displayEngine.pushSilence()`
- Replace the needle's data source with `displayEngine.displayCents`
- Drive the needle update with `TimelineView(.animation)` instead of relying on `onChange` + spring:

```swift
TimelineView(.animation) { timeline in
    let _ = displayEngine.update(now: CACurrentMediaTime())
    NeedleDisplay(cents: displayEngine.displayCents, dialWidth: dialWidth)
}
```

**Critical:** The `NeedleDisplay` Canvas should have NO `.animation()` modifier — the spring-damper in `TunerDisplayEngine` handles all smoothing. Adding a SwiftUI animation on top would recreate the double-smoothing problem.

**Extract the needle** into its own subview that only reads `displayEngine.displayCents`. The rest of TunerView (note header, cents readout, level bar, controls) should observe `PitchDetector` directly. This prevents 60fps needle updates from triggering recomputation of the entire view.

### Phase 2 Verification

- [ ] Run full test suite — ALL tests must pass
- [ ] Build and run on device (not just simulator) — play a real guitar into the tuner
- [ ] Verify: needle moves quickly when plucking a new string (coarse zone)
- [ ] Verify: needle settles smoothly when approaching in-tune (no jitter, no overshoot)
- [ ] Verify: needle holds steady when a note is sustaining (precision zone)
- [ ] Verify: needle returns smoothly to center when the note fades
- [ ] Verify: no visual flash or jump when transitioning between strings
- [ ] Verify: Quiz tab behavior is completely unchanged — run a short quiz session
- [ ] Verify: Calibration flow works normally
- [ ] If the spring-damper values feel wrong (too sluggish, too bouncy, etc.), adjust the `gainSchedule` stiffness and damping constants and retest. Document the final tuned values.
- [ ] Log to `BUGLOG.md` as `T6 | Tuner Phase 2 core architecture | TunerDisplayEngine, tracking mode, cents-space filtering, tuner fast path, adaptive YIN threshold, transient suppression`

---

## PHASE 3: Visual Presentation Layer

**Goal:** Premium visuals. Glanceable. Rewarding. The tuner looks like it belongs next to a Peterson StroboClip.

### 3A. Dual display — settled readout

**File:** `TunerDisplayEngine.swift`

**Add settled-value logic** to the `update()` method:

```swift
// After computing displayCents, track stability for settled readout
private var stabilityBuffer: [Double] = []
private var stableStartTime: CFTimeInterval? = nil

// Inside update(), after displayCents is computed:
stabilityBuffer.append(displayCents)
if stabilityBuffer.count > 20 { stabilityBuffer.removeFirst() } // ~330ms at 60fps

if stabilityBuffer.count >= 18 {
    let mean = stabilityBuffer.reduce(0, +) / Double(stabilityBuffer.count)
    let maxDeviation = stabilityBuffer.map { abs($0 - mean) }.max() ?? 999
    if maxDeviation < 0.5 {
        // Stable for ~300ms — update settled readout
        if stableStartTime == nil { stableStartTime = now }
        if now - (stableStartTime ?? now) > 0.3 {
            settledCents = mean
        }
    } else {
        stableStartTime = nil
        settledCents = nil
    }
}
```

**File:** `TunerView.swift`

**Add** a settled readout below the dial. When `displayEngine.settledCents` is non-nil, show it in JetBrains Mono Bold, 28pt. When it equals "IN TUNE" range (|value| < 1.0), show "IN TUNE" in Montserrat Bold instead of the number. Use the same tuning color logic.

### 3B. In-tune state with wide hysteresis

**File:** `TunerView.swift` (or a new `TunerStateManager` if you prefer)

**Add a state machine:**

```swift
enum TuningState {
    case offPitch
    case approaching
    case inTune
}

@State private var tuningState: TuningState = .offPitch
@State private var stateEntryTime: Date = .now
```

**Transition logic** (evaluated each time `settledCents` changes):

| From | To | Condition |
|------|----|-----------|
| offPitch | approaching | |settledCents| < 5.0 for 200ms |
| approaching | inTune | |settledCents| < 1.0 for 400ms |
| approaching | offPitch | |settledCents| > 5.0 for 200ms |
| inTune | offPitch | |settledCents| > 3.0 for 200ms |
| inTune | approaching | — (skip; goes directly to offPitch via wide exit) |

**Key:** The exit threshold from inTune (3.0¢) is much wider than the entry threshold (1.0¢). This prevents flicker.

### 3C. Background color wash

**File:** `TunerView.swift`

Apply a full-width color overlay behind all tuner content, driven by `tuningState`:

```swift
.background(
    Group {
        switch tuningState {
        case .offPitch:
            Color.clear
        case .approaching:
            DesignSystem.amber.opacity(0.06)
        case .inTune:
            DesignSystem.correct.opacity(0.08)
        }
    }
    .animation(.easeInOut(duration: 0.5), value: tuningState)
)
```

**Additionally**, when `tuningState == .inTune`:
- The green center zone on the dial glows (add a second overlapping arc with `.blur(radius: 8)` and `correct.opacity(0.4)`)
- The needle pivot dot pulses gold (use a repeating opacity animation)

### 3D. String indicator

**File:** `TunerView.swift` — below the note name display.

**Add** a string detection lookup based on detected frequency. When the PitchDetector reports a frequency, match it to the nearest open string:

```swift
func detectedString(frequency: Double) -> String? {
    let openStrings: [(name: String, freq: Double, label: String)] = [
        ("E2", 82.41, "6th String"),
        ("A2", 110.00, "5th String"),
        ("D3", 146.83, "4th String"),
        ("G3", 196.00, "3rd String"),
        ("B3", 246.94, "2nd String"),
        ("E4", 329.63, "1st String"),
    ]
    // Find the string whose open frequency is closest (within ±50 cents)
    // Account for octaves — E4 at 12th fret is still "1st String"
    // Use a reasonable range: open string freq × 0.95 to freq × 1.05
    // For notes above open string range, check if it's a standard harmonic/fret
}
```

Display as Montserrat Medium 14pt, `text2` color. Only show when a note is detected.

### 3E. Responsive dial sizing

**File:** `TunerView.swift` — find the fixed `frame(width: 340, height: 170)` on the dial.

**Replace** with:

```swift
GeometryReader { geo in
    let dialWidth = min(geo.size.width - 32, 400) // 16pt padding each side, max 400
    let dialHeight = dialWidth / 2
    // Pass dialWidth to all Canvas drawing functions
    NeedleDisplay(cents: displayEngine.displayCents, dialWidth: dialWidth)
        .frame(width: dialWidth, height: dialHeight)
}
```

All Canvas drawing parameters (needle length, arc radius, tick positions, font sizes) should be derived from `dialWidth` as a single source of truth. Use proportional values, not absolute points.

### 3F. Auto-hide input level bar

**File:** `TunerView.swift`

**Add:**

```swift
@State private var levelBarOpacity: Double = 1.0
@State private var goodSignalSince: Date? = nil
```

When the input level is between 0.1 and 0.9, track `goodSignalSince`. After 3 seconds of good signal, animate `levelBarOpacity` to `0.3`. If signal drops below 0.1 or clips above 0.9, reset `goodSignalSince = nil` and animate back to `1.0`.

Apply `.opacity(levelBarOpacity).animation(.easeInOut(duration: 0.3), value: levelBarOpacity)` to the level bar.

### Phase 3 Verification

- [ ] Run full test suite — ALL tests pass
- [ ] Build and run on device with real guitar
- [ ] Verify: settled cents readout appears below dial after ~300ms of stable pitch
- [ ] Verify: settled readout shows "IN TUNE" when pitch is within ±1¢
- [ ] Verify: background color subtly shifts amber when approaching, green when in-tune
- [ ] Verify: green "in-tune" state does NOT flicker — once green, stays green until pitch moves >3¢ away
- [ ] Verify: string indicator shows "6th String", "5th String", etc. correctly for open strings
- [ ] Verify: dial scales to screen width on different device sizes (SE vs Pro Max)
- [ ] Verify: input level bar fades after 3 seconds of good signal
- [ ] Verify: needle glow + pivot pulse appear in the in-tune state
- [ ] Verify: Quiz tab is completely unchanged
- [ ] Log to `BUGLOG.md` as `T7 | Tuner Phase 3 visual presentation | Settled readout, in-tune hysteresis, background wash, string indicator, responsive dial, auto-hide level bar`

---

## PHASE 4: Differentiators

**Goal:** Features no competitor offers. These make FretShed's tuner a reason to keep the app even beyond fretboard training.

### 4A. Intonation comparison mode

**File:** `TunerView.swift` (or extract into a new `IntonationView.swift` if the file is getting large)

**Add a mode toggle** in the tuner — a small button or segmented control at the top: "Tuner" / "Intonation". When "Intonation" is selected, the UI changes:

**State machine:**

```swift
enum IntonationStep {
    case waitingForReference    // "Play the open string"
    case referenceAcquired(note: String, cents: Double)  // "Now play the 12th fret"
    case comparing(refNote: String, refCents: Double, frettedNote: String, frettedCents: Double)
}
```

**Workflow:**
1. User selects "Intonation" mode → display shows "Play the open string" instruction
2. User plays open string → settled cents locks → display shows "Open: E₂ +0.3¢" with a "Lock" button
3. User taps "Lock" → reference saved → display shows "Now play the 12th fret"
4. User plays 12th fret fretted note → display shows live delta:
   ```
   Open:    E₂  +0.3¢
   Fretted: E₄  +2.1¢
   Delta:   +1.8¢ sharp
   ```
5. Delta color: green (<±2¢), amber (±2-5¢), red (>±5¢)
6. Below the delta, show guidance text: "Sharp → move saddle back" or "Flat → move saddle forward" or "Good intonation ✓"
7. A "Reset" button returns to step 1

**Design:** Use Woodshop card styling for the reference/comparison display. The dial still shows the live needle in the background.

**Leave unchanged:** The main tuner mode. Intonation mode is an additive overlay, not a replacement.

### 4B. Pitch rate predictor

**File:** `TunerDisplayEngine.swift`

**Add:**

```swift
private(set) var predictorCents: Double? = nil
private var rateHistory: [Double] = [] // last 5 cents values for rate computation

// In update(), after computing targetCents:
rateHistory.append(targetCents)
if rateHistory.count > 5 { rateHistory.removeFirst() }

if rateHistory.count >= 3 {
    let rate = (rateHistory.last! - rateHistory[rateHistory.count - 3]) / (3.0 / 60.0) // cents per second
    if abs(rate) > 2.0 { // Only show predictor when rate is meaningful
        predictorCents = displayCents + rate * 0.75 // 750ms lookahead
        predictorCents = max(-50, min(50, predictorCents!))
    } else {
        predictorCents = nil
    }
} else {
    predictorCents = nil
}
```

**File:** `TunerView.swift` — in the needle Canvas

**Add** a ghost needle (thin line, 30% opacity, amber color) at the `predictorCents` angle, only when `displayEngine.predictorCents != nil`. This shows the user where the pitch is heading while they turn the peg.

### 4C. Adaptive update rate

**File:** `TunerView.swift` — the `TimelineView`

**Replace** `.animation` schedule with a custom schedule based on tuning state:

```swift
TimelineView(TunerSchedule(state: tuningState, hasNote: detector.detectedNote != nil)) { timeline in
    let _ = displayEngine.update(now: CACurrentMediaTime())
    // ... needle display
}
```

Where `TunerSchedule` is a custom `TimelineSchedule`:

| State | Update rate |
|-------|------------|
| No note detected | ~10 fps |
| Note detected, offPitch (>15¢) | ~30 fps |
| Note detected, fine tuning (<15¢) | ~60 fps |
| In-tune locked | ~15 fps |

This saves battery and CPU during idle periods while maintaining maximum visual quality during active tuning.

### Phase 4 Verification

- [ ] Run full test suite — ALL tests pass
- [ ] Intonation mode: complete a full open-string → 12th-fret comparison on all 6 strings
- [ ] Intonation mode: verify delta display is accurate (compare with a known tuner)
- [ ] Intonation mode: verify "Reset" returns to step 1 cleanly
- [ ] Predictor: while turning a tuning peg, verify the ghost needle appears ahead of the main needle and collapses when you stop turning
- [ ] Predictor: verify the ghost needle is NOT visible during steady state (not turning)
- [ ] Adaptive rate: verify no visual difference during active tuning (should still be smooth)
- [ ] Quiz tab: completely unchanged
- [ ] Log to `BUGLOG.md` as `T8 | Tuner Phase 4 differentiators | Intonation comparison mode, pitch rate predictor, adaptive update rate`

---

## Post-Phase Cleanup

After all phases are complete:

1. **Update `CLAUDE.md`** — add a "Tuner Architecture" section documenting the three-layer design, the `TunerDisplayEngine` class, the gain schedule values, and the intonation mode state machine.

2. **Update `ROADMAP.md`** — add the tuner rewrite as a completed phase (or add tasks within the appropriate existing phase).

3. **Update `BUGLOG.md`** — ensure all changes are logged with session dates.

4. **Add to Sync Ledger** in `ROADMAP.md`:
   - Outbound: "Tuner rewrite complete (Phases 1-4). New files: TunerDisplayEngine.swift. Modified: TunerView.swift, PitchDetector.swift, AccelerateYIN.swift. Claude.ai needs to update ROADMAP_STRATEGY.md."

5. **Run final full test suite** and report results.

---

## Reference: Gain Schedule Tuning Guide

If the needle doesn't feel right after Phase 2, here's how to adjust:

| Symptom | Adjust | Direction |
|---------|--------|-----------|
| Needle too sluggish overall | Increase stiffness in all zones | +100-200 |
| Needle overshoots in fine zone | Increase damping in fine zone | +5-10 |
| Needle hunts/oscillates in precision zone | Increase damping in precision zone | +5-10 OR decrease stiffness -50 |
| Needle snaps too aggressively to new notes | Decrease stiffness in coarse zone | -100-200 |
| Needle takes too long to settle | Decrease damping (all zones) | -5 |
| Transition between zones feels abrupt | Add a linear interpolation between zone boundaries | Blend stiffness/damping values |

The ideal behavior: pluck a string and the needle arrives at the correct position in <300ms with no overshoot. Slowly turn a peg and the needle tracks smoothly with no lag or stutter. Stop turning and the needle settles to its final position within 200ms with no ringing.
