# FretShed — Claude Development Guide

## Start of Every Session
1. Read this file fully
2. Read ROADMAP.md to know current task status
3. Run `find . -name "*.swift" | sort > FILE_MANIFEST.txt` and review it
4. Confirm which task we are working on before writing any code

---

## Project Overview
FretShed is an iOS guitar fretboard training application that helps guitarists memorize notes across the fretboard. Core differentiator: **calibrated pitch detection + Bayesian adaptive learning** — "the fretboard trainer that actually gets your notes right."

> **Positioning note (Feb 2026):** Multiple competitors offer mic-based audio detection for fretboard training (Fret Pro, Solo, Guitar Blast, Fretonomy, plus broader apps like Yousician). FretShed is NOT "the only app that listens." Our defensible differentiators are: (1) environment calibration — no competitor calibrates to the user's room/guitar/input source; (2) Bayesian adaptive mastery scoring — no competitor dynamically weights quiz selection per fretboard position; (3) all-in-one practice toolkit (tuner + metronome + drone). See `FretShed_Competitive_Analysis.md` in the Claude.ai project for full details.

**App Store name:** FretShed: Guitar Fretboard  
**Subtitle:** Note Trainer & Ear Training  
**Bundle ID:** com.jpm.fretshed (set in App Store Connect — do not change once submitted)

---

## Technical Stack
- **Platform:** iOS 17+ (minimum deployment target — do not raise to iOS 18)
- **UI:** SwiftUI with @Observable architecture
- **Data:** SwiftData
- **Concurrency:** async/await throughout
- **Pitch Detection:** AccelerateYIN algorithm (Accelerate framework)
- **Signal Processing:** Accelerate vDSP (RMS, FFT, biquad IIR filters)
- **Mastery Scoring:** Bayesian scoring algorithm
- **Fretboard UI:** Canvas-based rendering
- **Monetization:** StoreKit 2
- **Audio:** AVAudioEngine + AVAudioSession

## Key Architecture
- **AppContainer:** Dependency injection container — all services injected here
- **EntitlementManager:** Central authority for feature access (free vs. premium) [Phase 4]
- **CalibrationProfileRepository:** Persists single calibration profile (SwiftData)
- **CalibrationEngine:** Orchestrates the calibration procedure (silence → 6 strings → save)
- **PitchDetector:** Pre-seeded with calibrated noise floor + AGC gain on quiz start

---

## App Structure (5 Tabs)
1. **Practice** — Session setup and quiz launch
2. **Progress** — Heatmap, mastery rings, session history
3. **Tuner** — AccelerateYIN-powered chromatic tuner
4. **MetroDrone** — Metronome + drone tone
5. **Settings** — Display, Audio, Quiz Defaults, Data Management, **Audio Setup (new)**

---

## Audio Calibration System (Implemented Feb 2026)

FretShed includes a full audio calibration system that measures the user's environment and guitar once, stores the results, and pre-seeds the pitch detector on quiz start — eliminating the 5-10 second adaptation warmup and improving first-note accuracy.

### Architecture
- **Single profile** — one `AudioCalibrationProfile` stored at a time; re-calibration overwrites it
- **Required before quiz** — `hasCompletedCalibration` UserDefaults flag gates quiz launch
- **All 6 strings required** — no skip during string test

### Signal Processing Chain (in order)
```
HPF (60Hz Butterworth) → Adaptive Noise Gate → AGC (target −18 dBFS) → Low-Frequency Emphasis (input-source-aware) → Crest Factor + Spectral Subtraction (adaptive noise removal) → Tonal Signal Gate (crest factor OR harmonic regularity OR spectral flatness) → AccelerateYIN + HPS Verification + Harmonic Regularity → Tap Confidence Floor (sustainMode: 0.51, quiz: 0.85) → Consumer Confidence Hysteresis (sustainMode: 0.65 once established) → Note Decision (consecutive frame gate + string-aware frequency constraint + 500ms/250ms hold)
```

### Input Sources Detected
- `builtInMic` — Built-in iPhone microphone
- `usbInterface` — External USB audio interface (via Lightning/USB-C)
- `bluetoothAudio` — Bluetooth audio input
- `wiredHeadset` — Wired headset with inline microphone

### AudioCalibrationProfile (SwiftData model)
```swift
@Model public final class AudioCalibrationProfile {
    var inputSourceRaw: String            // AudioInputSource raw value
    var measuredNoiseFloorRMS: Float      // Median of 30 readings over 3s silence
    var measuredAGCGain: Float            // AGC gain captured after string test
    var calibrationDate: Date
    var signalQualityScore: Float         // 0.0–1.0 (fraction of strings detected)
    var userGainTrimDB: Float             // Manual trim, ±6 dB, default 0.0
    var userGateTrimDB: Float             // Manual trim, ±6 dB, default 0.0
    var stringResultsData: Data           // JSON-encoded [Int: Bool] (string → passed)
}
```

### CalibrationEngine Phases
```
.welcome → .measuringNoise(progress:) → .testingString(number:) → .complete
```
- **Silence:** Starts PitchDetector, samples `currentNoiseFloor` every 100ms for 3s (30 readings), takes median
- **Strings:** Guides through all 6 open strings (6→1: E, A, D, G, B, E), marks passed when expected note detected
- **Complete:** Captures AGC gain, builds profile, saves to SwiftData

### CalibrationView (4-screen TabView(.page))
| Screen | Content |
|--------|---------|
| 0 — Welcome | Explanation, detected input source, "Start" button |
| 1 — Silence | "Stay quiet for 3 seconds", InputLevelBar, progress ring, auto-advances |
| 2 — Strings | "Play String N (note)", live detection display, checkmarks |
| 3 — Results | Quality score ring, per-string checkmarks, "Save & Close" button |

### Quiz Integration
QuizView `.task` loads `calibrationRepository.activeProfile()` and pre-seeds:
- `detector.calibratedNoiseFloor = profile.measuredNoiseFloorRMS * gateTrimMultiplier`
- `detector.calibratedAGCGain = profile.measuredAGCGain * gainTrimMultiplier`

### Practice Tab — Do This First Card
- **Before calibration:** Full card with "Open Tuner" + "Calibrate Audio" buttons
- **After calibration:** Compact status line with green checkmark + "Re-calibrate" link

### Settings > Audio Setup Section
- Calibration status (Completed / Not Done)
- If calibrated: input source, date, signal quality badge (green/yellow/red)
- User trim sliders: Input Gain Trim (±6 dB), Noise Gate Trim (±6 dB)
- "Re-Calibrate" / "Run Calibration" button → fullScreenCover

---

## Competitive Landscape (Updated Feb 2026)

**DO NOT claim FretShed is "the only app that listens to you play."** This is false.

### Direct Competitors (Fretboard-Focused + Audio Detection)
| App | Audio Detection | Calibration | Adaptive Learning | Heatmap | Tuner/Metro/Drone |
|---|---|---|---|---|---|
| **Fret Pro** | ✅ (mic/interface) | ❌ | Spaced repetition | ❌ | ❌ |
| **Solo** (Tom Quayle) | ✅ (mic/interface) | ❌ | ❌ | ❌ | ❌ |
| **Guitar Blast** | ✅ (mic) | ❌ | ❌ | ❌ | ❌ |
| **Fretonomy** | ✅ (mic) | ❌ | ❌ | ✅ | Basic |
| **FretShed** | ✅ (mic/interface) | ✅ | ✅ (Bayesian) | ✅ | ✅ |

### FretShed's Defensible Differentiators
1. **Environment calibration** — No competitor calibrates to the user's room noise, guitar signal, and input source
2. **Bayesian adaptive mastery** — Per-position scoring dynamically weights quiz selection toward weak spots
3. **All-in-one practice toolkit** — Tuner + metronome + drone in the same app
4. **Detection reliability** — Competitor reviews consistently cite missed notes, false triggers, and stuck detection

### Approved Positioning Language
- ✅ "The fretboard trainer that actually gets your notes right"
- ✅ "Calibrated to your guitar. Adaptive to your progress."
- ✅ "The smartest way to master your fretboard"
- ❌ NEVER: "The only app that listens to you play" or any "only" claim about audio detection

Full analysis: `FretShed_Competitive_Analysis.md` in Claude.ai project files.

---

## Monetization Model (Phase 4)
- **Free tier:** Single Note mode, strings 4–6, frets 0–7, tap input, 7-day history, built-in mic calibration
- **Premium ($4.99/mo or $29.99/yr):** Full fretboard, all input source calibration profiles, chord progressions, extended history, unlimited audio detection sessions
- **Trial:** 7-day free trial on both plans
- **Subscription Group:** "FretShed Premium"
- **Product IDs:** `com.jpm.fretshed.premium.monthly`, `com.jpm.fretshed.premium.annual`

---

## Coding Standards
- Use @Observable (not ObservableObject) for all view models and services
- Use async/await for all asynchronous operations — no completion handlers
- Use SwiftData for all persistence — no CoreData, no UserDefaults for data (UserDefaults only for flags like `hasCompletedOnboarding`)
- Target iOS 17 API only — do not use iOS 18-exclusive APIs without a `#available` check
- Use Accelerate/vDSP for all signal processing — not custom loops
- All new audio processing code must be unit testable — extract pure functions from AVAudioEngine callbacks
- Always check for existing files in FILE_MANIFEST.txt before creating new Swift files

## File Creation Rules
- **Always check FILE_MANIFEST.txt first** to avoid creating duplicate files
- New files go in the appropriate group folder matching the existing project structure
- Signal processing utilities → `Audio/` group
- Calibration classes → `Audio/Calibration/` group
- SwiftData models → `Models/` group
- Views → appropriate tab subfolder under `Views/`

---

## Testing
- Test suite: 219 tests passing
- Run: `xcodebuild test -scheme FretShed -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- All tests must pass before marking any task complete
- New audio processing functions should have unit tests using pre-recorded PCM buffer fixtures

---

## Project Management
- **ROADMAP.md** — Source of truth for task status. Update it at the end of every session.
- **BUGLOG.md** — All device-testing issues logged here. Fix before shipping.
- **GitHub** — Commit after every completed task with message: `[Task X.Y] description`
- **MVP Checklist** — Canonical task list with descriptions and time estimates (stored in Claude.ai project)
- **Audio Calibration Feature Plan** — Full implementation spec for all calibration tasks (stored in Claude.ai project)

### Task Status Format (ROADMAP.md)
```
[x] = Complete
[-] = In Progress  
[ ] = Not Started
```

---

## Current Status (as of Feb 2026)
**Phase 1:** Tasks 1.1–1.8 complete ✅
**Phase 2:** Tasks 2.1–2.17 complete ✅ (Design System fully applied to all tabs)
**Phase 3:** Tasks 3.1–3.6 complete ✅ · Task 3.7 🔲 (device timing test)
**Phase 4:** Not started
**Phase 5:** Not started
**Test suite:** 219 tests passing

**Audio Calibration System (F22) — IMPLEMENTED.** Full calibration flow: silence measurement → 6-string test → profile saved to SwiftData. Quiz launch gated on calibration. Do This First card with action buttons. Settings > Audio Setup with trim sliders. PitchDetector pre-seeded from calibration profile. Single profile (re-calibrate overwrites).

**Pitch Detection Enhancements (F23) — IMPLEMENTED.** Five improvements to reduce false detections: (1) Spectral flatness gate rejects broadband string slide noise; (2) Consecutive frame gate requires 3 frames of same note; (3) HPF lowered to 60 Hz for better low-string fundamental capture; (4) String-aware frequency constraints narrow detection to target string's Hz range during quiz; (5) HPS octave verification cross-checks YIN with Harmonic Product Spectrum for low-string octave correction.

**DSP Enhancements (F24) — IMPLEMENTED.** Two signal processing improvements: (1) Low-frequency emphasis — input-source-aware 1st-order IIR low-shelf boost below ~250 Hz, compensates MEMS mic roll-off on wound strings (+6 dB built-in mic, +3.5 dB wired headset, off for USB); (2) Adaptive spectral subtraction — captures running noise spectrum estimate (EMA, alpha=0.05) during gate-closed silence periods, subtracts 1.5× over-subtracted noise from power spectrum with spectral flooring before YIN analysis, extends usable detection from "quiet room" to "room with background noise."

**Distortion Tolerance (F25) — IMPLEMENTED.** Three improvements for distorted guitar signals: (1) Crest factor bypass — `vDSP_maxmgv/vDSP_rmsqv` computes peak/RMS ratio; crest < 2.0 indicates clipping (distortion pedal), bypasses flatness gate; (2) Input-source-aware flatness threshold — USB interface relaxed to 0.50 (vs 0.35 for mic/headset) since distortion pedals are only relevant through interfaces; (3) Harmonic spacing regularity — sums power at first 10 integer multiples of HPS fundamental (±1 bin), divides by total power; ratio > 0.3 indicates tonal signal (even if spectrally flat from distortion), bypasses flatness gate. Three-way tonal signal check: `crestFactor < 2.0 || harmonicReg > 0.3 || flatness < threshold`.

**Tuner Sustain Hysteresis (F29) — IMPLEMENTED.** Fixes 12th-fret sustain dropout where the tuner needle drops while the note is still ringing. Three-layer approach: (1) `sustainMode` flag on PitchDetector — TunerView sets true, QuizView leaves false (default); (2) Tap floor lowered to 60% of confidenceThreshold in sustain mode (0.51 vs 0.85) to pass decay-phase frames; (3) Consumer-side confidence hysteresis — once a note is established (consecutive gate met), accepts confidence >= 0.65 to extend sustain; hold window doubled to 500ms. TunerView onChange split into two handlers: detectedNote (resets displayCents on nil→some) and centsDeviation (amplitude-aware EMA only while note active). Quiz behavior is byte-for-byte identical — sustainMode defaults to false, tap floor and hysteresis are both gated.

**Session Data Backup & Restore (F30) — IMPLEMENTED.** JSON export/import in Settings > Data Management. BackupPayload Codable structs decoupled from SwiftData models. BackupManager handles export to Documents directory and import with security-scoped resource access. Files visible in iOS Files app via UIFileSharingEnabled.

**Crash Fix (C1) — FIXED.** PitchDetector crash on infinite/NaN Double→Int conversion. Root cause: YIN parabolic interpolation produces `interpolatedTau ≤ 0` when `bestTau=1`, making `sampleRate / interpolatedTau` infinite. Two-layer fix: guard in `detectPitch()` + defense in `pitchDetectorNoteAndCents()`.

**All BUGLOG items resolved.** All feature ideas (F1–F30) complete.

**Next task:** Task 3.7 (onboarding device test), then Phase 4.

**Quiz Presentation Architecture (current — ZStack overlay + direct closures):**
- `ContentView.body` is `ZStack { TabView { ... }; if let vm = activeQuizVM { quizOverlay(vm: vm).zIndex(1) } }`
- Quiz is a ZStack overlay ABOVE the TabView — no NavigationStack push, no navigation path
- `launchQuiz(vm:)` simply sets `activeQuizVM = vm` + `selectedTab = .practice`; no path manipulation
- `QuizSessionView` (private struct) accepts `onDone / onViewProgress / onRepeat` as direct closures; swaps `QuizView` → `SessionSummaryView` via `@State showResults`
- `SessionSummaryView` has `onDone / onViewProgress / onRepeat: (() -> Void)?` properties; buttons call these closures directly — NO NotificationCenter.post in any button
- ContentView `onReceive` handlers retained only for `.launchQuiz` (from PracticeHomeView) and `.showPracticeTab` (from ProgressTabView empty state)
- Repeat logic lives in `launchRepeatSession(from:)` on ContentView, called from the `onRepeat` closure
- **Why ZStack over NavigationStack push:** onReceive handlers did not fire reliably while a pushed destination was active on iOS 26; NavigationStack destination also had a timing window where activeQuizVM was nil, producing a blank page
- **Why closures over notifications:** eliminates the RunLoop-scheduled Combine dispatch chain entirely; closure → state mutation is synchronous and direct

---

## Session End Protocol

**Every Claude Code session must end with this checklist. Do not consider a session complete until all steps are done.**

**Trigger phrases:** "wrap up", "end session", "that's it for today", "commit and push", "good night", "goodnight", "gn", or similar.

1. **Run the test suite**
   ```bash
   xcodebuild test -scheme FretShed -destination 'platform=iOS Simulator,id=AD41361D-9AAA-48E6-A848-07CE3E23C663' 2>&1 | tail -20
   ```
   Report pass/fail count. Do not proceed if new failures were introduced.

2. **Update FILE_MANIFEST.txt**
   ```bash
   find . -name "*.swift" | sort > FILE_MANIFEST.txt
   ```

3. **Update ROADMAP.md** — Mark any completed tasks as ✅ and any in-progress tasks as 🚧.

4. **Update CLAUDE.md** — If any architectural decisions were made, features implemented, or bugs fixed, update the Current Status section and any relevant sections.

5. **Stage and review changes**
   ```bash
   git status
   git diff --stat
   ```
   Show the user what will be committed. Stage specific files by name (avoid `git add -A` which can accidentally include sensitive files like .env or credentials). Wait for confirmation if the diff is large.

6. **Commit with a descriptive message**
   ```bash
   git commit -m "[Task X.Y] Brief description of what was done"
   ```
   Use the task number from ROADMAP.md if applicable. For multi-task sessions, use multiple commits or a summary message.

7. **Push to remote**
   ```bash
   git push
   ```

8. **Print a session summary** — A brief recap of:
   - What was accomplished
   - What tasks are now complete
   - What the next task is (per ROADMAP.md)
   - Whether any project docs were changed that need to be re-uploaded to Claude.ai Project Knowledge (flag this explicitly so the user knows)

**If project docs (CLAUDE.md, ROADMAP.md, etc.) were modified, remind the user:**
> "CLAUDE.md / ROADMAP.md was updated this session. Remember to re-upload the updated version(s) to your Claude.ai Project Knowledge so both interfaces stay in sync."

---

## Known Issues (from BUGLOG.md)
All device-testing bugs are resolved. All feature ideas (F1–F30) are complete.

---

## Reference Documents (in Claude.ai Project)
- `FretShed_MVP_Checklist_v2.docx` — Full task list with all calibration tasks integrated
- `FretShed_AudioCalibration_Plan.docx` — Detailed implementation spec for calibration system
- `FretShed_Competitive_Analysis.md` — Full competitive landscape analysis with feature matrix and revised positioning (Feb 2026)
- `TEAM_OF_EXPERTS.md` — Prompt engineering personas for domain-specific guidance (invoke by name: Shred McStackview, Droptuned Doug, Chromatic Chris, Fretwise Freddie, Paywall Pete, Feedback Fiona, Lyric Lisa, Compliance Cliff, Encore Eddie, A11y Axel)

---

## Action Items from Competitive Analysis
- [ ] Update onboarding subtitle in code: change "The guitar trainer that actually listens to you play" → "The guitar trainer that actually gets your notes right" (if already implemented in OnboardingView.swift)
- [ ] When writing App Store description (Task 5.12): use revised positioning from competitive analysis — lead with calibration + adaptive learning, NOT "only app that listens"
- [ ] When creating App Store screenshots (Task 5.2): feature the calibration flow as a key differentiator
