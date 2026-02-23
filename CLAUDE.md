# FretShed — Claude Development Guide

## Start of Every Session
1. Read this file fully
2. Read ROADMAP.md to know current task status
3. Run `find . -name "*.swift" | sort > FILE_MANIFEST.txt` and review it
4. Confirm which task we are working on before writing any code

---

## Project Overview
FretShed is an iOS guitar fretboard training application that helps guitarists memorize notes across the fretboard. Core differentiator: **reliable pitch detection + adaptive learning** — "the only fretboard trainer that listens to you play."

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
- **EntitlementManager:** Central authority for feature access (free vs. premium)
- **AudioProfileStore:** Persists calibration profiles per input source (SwiftData)
- **CalibrationEngine:** Orchestrates the full calibration procedure
- **AdaptiveMonitor:** Real-time signal quality monitoring during quiz sessions

---

## App Structure (5 Tabs)
1. **Practice** — Session setup and quiz launch
2. **Progress** — Heatmap, mastery rings, session history
3. **Tuner** — AccelerateYIN-powered chromatic tuner
4. **MetroDrone** — Metronome + drone tone
5. **Settings** — Display, Audio, Quiz Defaults, Data Management, **Audio Setup (new)**

---

## Audio Calibration System (New — Added Feb 2026)

FretShed includes a full audio calibration system that characterizes each user's guitar, input source, and environment before quiz sessions begin. This is the feature that makes pitch detection reliable across all guitar types (including hollow body) and all input sources.

### Signal Processing Chain (in order)
```
Input Source → Input Gain Stage → Noise Gate → Transient Suppressor 
→ High-Pass Filter (70Hz) → Harmonic Weighter → AccelerateYIN → Note Decision
```

### Input Sources Supported
- `builtInMic` — Built-in iPhone microphone
- `usbInterface` — External USB audio interface (via Lightning/USB-C)
- `bluetoothAudio` — Bluetooth audio input (simplified profile — see note)
- `wiredHeadset` — Wired headset with inline microphone

> **Bluetooth note:** Due to Bluetooth latency characteristics, Bluetooth input uses a simplified fixed-gain profile without per-string harmonic calibration. Display a note to the user: "Bluetooth audio may affect detection accuracy."

### AudioCalibrationProfile (SwiftData model)
```swift
// Per input source — stored and loaded automatically on route change
var inputSource: AudioInputSource
var inputGainMultiplier: Float       // Pre-calculated gain to reach −18 to −12 dBFS RMS
var noiseGateThresholdDB: Float      // Auto (noise floor + 12dB) + userGateTrimDB
var noiseGateReleaseSeconds: Float   // Default 0.080
var harmonicWeightingProfile: [Float] // Per-string (6 values), index 0 = low E
var calibrationDate: Date
var signalQualityScore: Float        // 0.0–1.0
var userGainTrimDB: Float            // Manual user delta, default 0.0, range ±6dB
var userGateTrimDB: Float            // Manual user delta, default 0.0, range ±6dB
```

### Signal Processing Parameters
| Stage | Key Parameters |
|---|---|
| Input Gain | Target RMS: −18 to −12 dBFS |
| Noise Gate | Threshold = noise floor + 12dB; Release = 80ms |
| Transient Suppressor | Attack = 1ms, Release = 40ms, Ratio 4:1 |
| High-Pass Filter | 70Hz, 2nd-order Butterworth via vDSP biquad IIR |
| Harmonic Weighter | Per-string FFT weighting; fundamental emphasis |

### AdaptiveMonitor — Bounded Adjustment Rules (session-only, never writes to profile)
- RMS rises >6dB above calibrated baseline → reduce gain by up to 4dB
- Noise floor rises >6dB → raise gate threshold by up to 4dB  
- YIN confidence <0.3 for 5+ consecutive detections → raise amplitude threshold
- False trigger rate >20% → tighten gate release by 20ms

### Signal Quality Indicator (quiz UI)
- 🟢 Green — operating at calibrated accuracy
- 🟡 Yellow — degraded, monitor adapting
- 🔴 Red — significantly degraded, show notification banner

### Calibration Onboarding Sequence (Screens 4–7)
1. **Screen 4:** Input source detection — show active source, allow switching
2. **Screen 5:** Silence measurement — 3 seconds, shows live dB meter, sets noise gate
3. **Screen 6:** Open string test — play each string low E to high e, captures per-string profile
4. **Screen 7:** Results summary — green checkmarks, option to re-run or proceed

### Re-Calibration from Settings
Settings > Audio Setup shows: current source, calibration date, quality score.  
Controls: Input Gain trim slider (±6dB), Noise Gate trim slider (±6dB).  
Buttons: Re-Calibrate (opens screens 5–7 as modal), Reset to defaults.

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
- Test suite: 206 tests passing
- Run: `xcodebuild test -scheme FretShed -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- All tests must pass before marking any task complete
- New audio processing functions (gain, gate, transient, HPF, harmonic weighter) should each have unit tests using pre-recorded PCM buffer fixtures

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
**Phase 3:** Tasks 3.1–3.6 complete ✅ · Task 3.7 🔲 (device timing test — blocked by Q6)
**Phase 4:** Not started
**Phase 5:** Not started

**🚨 Blocking Bug — Q6:** Results page buttons (Done, View Progress, Repeat) do not respond to taps on iPhone 16 Pro (iOS 26.2.1). Seven presentation approaches tried across two sessions. Current architecture: `fullScreenCover` on `TabView` driven by `activeQuizVM: QuizViewModel?` in `ContentView`; all button actions post `NotificationCenter` notifications handled by `ContentView`. This resolves correctly in simulator but buttons remain dead on device.

**Next task after Q6 resolved:** Task 3.7 (onboarding device test), then Phase 4.

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

## Known Issues (from BUGLOG.md)
Update this section when new bugs are discovered during device testing.

---

## Reference Documents (in Claude.ai Project)
- `FretShed_MVP_Checklist_v2.docx` — Full task list with all calibration tasks integrated
- `FretShed_AudioCalibration_Plan.docx` — Detailed implementation spec for calibration system
