# FretMaster

iOS guitar fretboard learning app built with SwiftUI (iOS 17.0+) and SwiftData. Helps users master note identification through interactive quizzes, progress tracking, and practice tools.

**Goal**: App Store launch. See `ROADMAP.md` for the 5-phase plan (Cleanup → Design System → Onboarding → Monetization → Submission).

> **Naming note**: The Xcode project/scheme is `FretMaster`. The target product name is `FretSmart`. The bundle ID must be decided before Phase 4 — it is permanent once submitted to App Store Connect.

## Project Type

Xcode iOS project (not SPM). Swift 6.0 strict concurrency. Deployment target: iOS 17.0. Test target: `FretMasterTests`.

```bash
# Build
xcodebuild -scheme FretMaster -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Test (189 tests)
xcodebuild test -scheme FretMaster -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Architecture

```
App/                 # @main entry, TabView, AppContainer (DI)
Audio/               # MetroDroneEngine (singleton — metronome, drone, sound cues)
Domain/Models/       # SwiftData models: Session, Attempt, MasteryScore, UserSettings
Domain/Repositories/ # Repository protocols (AttemptRepository, SessionRepository, etc.)
Data/SwiftData/      # Repository implementations
Quiz/                # Quiz feature: QuizView, QuizViewModel, SessionSetupView, FretboardView
Tuner/               # PitchDetector (AccelerateYIN), TunerView, SettingsView
Progress/            # ProgressTabView, heatmap, session history, cell detail
MetroDrone/          # Metronome + drone generator UI and view model
~~Presentation/~~    # DELETED — legacy duplicates removed in Phase 1 cleanup.
```

**Planned additions (Phases 2–4)**:
- `DesignSystem.swift` — centralized colors, typography, spacing (Phase 2)
- `Onboarding/OnboardingView.swift` — 4-screen first-launch flow (Phase 3)
- `Monetization/EntitlementManager.swift` — StoreKit 2, exposes `isPremium: Bool` (Phase 4)
- `Monetization/PaywallView.swift` — subscription UI (Phase 4)

**DI**: `AppContainer` holds repositories + `FretboardMap`, injected via `@Environment(\.appContainer)`. When adding `EntitlementManager` (Phase 4), inject it the same way.

**View Models**: `@MainActor @Observable` — QuizViewModel, ProgressViewModel, MetroDroneViewModel, PitchDetector.

## Five Tabs

1. **Practice** — Hero card, quick-start grid (Single Note, String Selector, Full Fretboard), full SessionSetupView for custom config. Launches QuizView full-screen.
2. **Progress** — 6x12 mastery heatmap (note x string), overall mastery ring, accuracy trend chart, recent sessions list with swipe-to-delete.
3. **Tuner** — Live pitch detection via mic (AccelerateYIN FFT autocorrelation), needle/strobe display, configurable reference A.
4. **MetroDrone** — Metronome (BPM 20-300, time signatures, beat accents, speed trainer) + drone generator (key, voicing, LFO, low-pass filter).
5. **Settings** — Display, tuner, audio, quiz defaults, sounds/haptics, notifications, data management.

## Quiz System

**7 Focus Modes**: Full Fretboard, Single Note, Single String, Fret Position, Circle of Fourths, Circle of Fifths, Chord Progression.

**4 Game Modes**: Relaxed (untimed), Timed, Streak (one wrong ends it), Tempo (shrinking timer).

**Adaptive weighting** (`session.isAdaptive`): Cross-cutting toggle ("Prioritize Weak Spots") that composes with any spatial focus mode. Skips mastered cells, heavily weights struggling ones (5x boost). Hidden for circle and chord progression modes.

**Circle sub-constraints**: Circle modes have a segmented picker (Full Fretboard / Strings / Position) to constrain which frets/strings are drilled while maintaining circle note order.

**Chord Progression**: 8 presets + custom builder, transposable to any key. Drills root, 3rd, 5th in close voicing for each chord.

**QuizViewModel state machine**: idle → active → feedbackCorrect/Wrong → complete. Pitch detection via PitchDetector feeds `submit(detectedNote:)`.

## Data Layer

**SwiftData schema**: Session, Attempt, MasteryScore, UserSettings.

**Bayesian mastery**: `(correct + alpha) / (total + alpha + beta)` where alpha=2, beta=1. Mastered: score >= 0.90 AND >= 15 attempts. Struggling: score < 0.50 AND >= 5 attempts.

**FretboardMap**: Pre-computed lookup table — 6 strings x 25 frets (standard tuning). Instant note-at-position and all-positions-for-note lookups.

## Audio

**MetroDroneEngine** (singleton): Shared between MetroDrone tab and Quiz. Click synthesis (noise + tonal), drone (additive harmonics + LFO + LPF), sound cues (correct/incorrect). Set `onBeat` before starting, clear after stopping.

**PitchDetector**: AccelerateYIN algorithm, raw-pointer ring buffer (1024 hop / 4096 window), route change handling. No Bluetooth HFP — uses `.allowBluetoothA2DP` only.

**Audio session**: `.playAndRecord` / `.measurement` with `.mixWithOthers` + `.allowBluetoothA2DP`.

## Critical Patterns

**Audio**:
- **Audio tap closures must be `@Sendable` free functions** — never formed inside `@MainActor` methods (runtime crash).
- **Never use Swift arrays in audio-thread shared state** — copy-on-write causes data races. Use fixed-size scalar fields (`freq0/freq1/freq2`), naturally atomic on ARM64.
- **Use `UnsafeMutablePointer<Float>`** for vDSP buffers and ring buffers to avoid pointer lifetime issues.
- **`@unchecked Sendable`** for mutable state shared with audio thread.

**Swift 6 / Observable**:
- **Never self-assign in `didSet` with `@Observable`** — `x = x.clamped(...)` inside `didSet` re-enters `withMutation`, crashing under Swift 6. Let UI controls constrain values instead.

**Monetization (Phase 4)**:
- Use StoreKit 2 (`Product.products`, `Transaction.currentEntitlements`) — not the old StoreKit 1 API.
- `EntitlementManager` must be `@MainActor @Observable` and injected via `AppContainer`.
- Free tier: Single Note mode, strings 4–6, frets 0–7, tap input, 7-day history. Everything else is premium.
- Paywall must include legal text: trial length, post-trial price, cancellation instructions (required — Apple will reject without it).

**App Store**:
- `PrivacyInfo.xcprivacy` must declare microphone usage and `NSUserDefaults` access before submission or the build will be auto-rejected.

## Testing

189 unit tests in `FretMasterTests/UnitTests/`. Uses in-memory SwiftData (`makeModelContainer(inMemory: true)`). Key test files:
- `QuizViewModelTests.swift` — state machine, focus modes, adaptive, streaks, tempo
- `MasteryAlgorithmTests.swift` — Bayesian scoring
- `MusicalNoteTests.swift` — note arithmetic, circles, transposition
- `ProgressViewModelTests.swift` — heatmap data, trends
- `FretboardMapTests.swift` — lookup table correctness
- `SettingsTests.swift` — persistence round-trips
- `PracticeLogTests.swift` — session logging

New tests should follow the same in-memory SwiftData pattern. When adding `EntitlementManager`, mock StoreKit with `StoreKitTest` framework rather than hitting the real sandbox.
