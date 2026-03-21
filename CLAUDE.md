## Start of Every Session
1. Read this file fully
2. Read ROADMAP.md to know current technical task status
3. **Scan the Sync Ledger in CLAUDE.md and ROADMAP.md** — find any 🔲 Pending inbound entries requested by Claude.ai. Apply them before starting new work.
4. Read CLAUDE_STRATEGY.md for business context (read only — do not edit)
5. Run `find . -name "*.swift" | sort > FILE_MANIFEST.txt` and review it
6. Confirm which task we are working on before writing any code

> **Why step 3 matters:** Claude.ai logs requested changes to the Sync Ledger. If Claude Code doesn't scan for pending inbound items at session start, those requests get missed — producing stale documentation and inconsistent state.

---

## Project Overview
FretShed is an iOS guitar fretboard training application that helps guitarists memorize notes across the fretboard. Core differentiator: **calibrated pitch detection + Bayesian adaptive learning** — "the fretboard trainer that actually gets your notes right."

> **Positioning note (Feb 2026):** Multiple competitors offer mic-based audio detection for fretboard training (Fret Pro, Solo, Guitar Blast, Fretonomy, plus broader apps like Yousician). FretShed is NOT "the only app that listens." Our defensible differentiators are: (1) environment calibration — no competitor calibrates to the user's room/guitar/input source; (2) Bayesian adaptive mastery scoring — no competitor dynamically weights quiz selection per fretboard position; (3) all-in-one practice toolkit (tuner + metronome + drone). See `FretShed_Competitive_Analysis.md` in the Claude.ai project for full details.

**App Store name:** FretShed: Guitar Fretboard  
**Subtitle:** Learn Every Fretboard Note
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
- **CalibrationProfileRepository:** Persists named calibration profiles (SwiftData) — supports multiple profiles per guitar
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

## Audio Calibration System (Implemented Feb 2026, Multi-Profile Mar 2026)

FretShed includes a full audio calibration system that measures the user's environment and guitar, stores the results as named profiles, and pre-seeds the pitch detector on quiz start — eliminating the 5-10 second adaptation warmup and improving first-note accuracy.

### Architecture
- **Multi-profile** — multiple `AudioCalibrationProfile` records, one per guitar; `isActive` flag selects the profile used for quizzes
- **Profile naming** — post-calibration flow prompts for name (e.g. "Strat") and guitar type (electric/acoustic/classical)
- **Re-calibration** — overwrites calibration data on existing profile, keeps name/type
- **Settings management** — profile list with context menu (set active, rename, re-calibrate, delete), swipe actions, "Add New Profile" button
- **Required before quiz** — `hasCompletedCalibration` UserDefaults flag gates quiz launch
- **All 6 strings required** — no skip during string test
- **Session tracking** — `calibrationProfileID` on Session records which profile was used
- **Upgrade path** — existing single profile auto-named "Guitar 1", marked active on first access

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
    var frettedStringResultsData: Data    // JSON-encoded [Int: Bool] (12th fret)
    var name: String?                     // User-assigned name (e.g. "Strat")
    var guitarTypeRaw: String?            // GuitarType raw value
    var isActive: Bool = false            // Active profile for quiz detection
}
```

### GuitarType enum
`.electric`, `.acoustic`, `.classical` — each with `displayName` and `iconName`.

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
| 3 — Results | Quality score ring, per-string checkmarks, profile naming (name + guitar type), "Save Profile" button |

### Quiz Integration
QuizView `.task` loads `calibrationRepository.activeProfile()` and pre-seeds:
- `detector.calibratedNoiseFloor = profile.measuredNoiseFloorRMS * gateTrimMultiplier`
- `detector.calibratedAGCGain = profile.measuredAGCGain * gainTrimMultiplier`

### Practice Tab — Do This First Card
- **Before calibration:** Full card with "Open Tuner" + "Calibrate Audio" buttons
- **After calibration:** Compact status line with green checkmark + "Re-calibrate" link

### Settings > Audio Setup Section
- Calibration status (Completed / Not Done)
- If calibrated: profile list with icon, name, "Active" badge, guitar type + input source + quality score
- Context menu per profile: Set Active, Rename, Re-Calibrate, Delete
- Swipe actions: Delete (trailing), Set Active (leading)
- User trim sliders for active profile: Input Gain Trim (±6 dB), Noise Gate Trim (±6 dB)
- "Add New Profile" / "Run Calibration" button → fullScreenCover
- Rename via alert with text field; delete with confirmation (warns if only profile)

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
- **Free tier:** Full experience on strings 4–6, frets 0–12. Free modes: Full Fretboard + Single String. Audio detection included. Full progress statistics and session history. Phase gate active — Phases 1 & 2 free on strings 4–6. Phase 3 (Connection) and Phase 4 (Fluency) require premium.
- **Premium ($4.99/mo, $29.99/yr, or $49.99 lifetime):** Full fretboard (all strings, all frets), all focus modes (Single Note, Fretboard Position, Circle of 4ths, Circle of 5ths, Chord Progression). Multiple saved named calibration profiles (USB/wired interface). Single calibration profile is free.
- **Trial:** 14-day free trial on monthly and annual plans
- **Subscription Group:** "FretShed Premium"
- **Product IDs:** `com.jpm.fretshed.premium.monthly`, `com.jpm.fretshed.premium.annual`, `com.jpm.fretshed.premium.lifetime`
- **Analytics:** TelemetryDeck (privacy-focused, no personal data collected)

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
- Test suite: 452 tests passing (0 failures)
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

## Current Status (as of Mar 2026)
**Phase 1:** Tasks 1.1–1.8 complete ✅
**Phase 2:** Tasks 2.1–2.17 complete ✅ (Design System fully applied to all tabs)
**Phase 3:** Tasks 3.1–3.7 complete ✅
**Phase 3.6:** Shed Redesign complete ✅ (SD.1–SD.15)
**Pre-Phase 4 Review:** Complete (6 batches)
**Smart Practice Redesign:** SP.1–SP.8 complete ✅
**Phase 4:** Not started
**Phase 5:** Not started
**Spacing Gate & Smart Review (SG.1–SG.9) — COMPLETE.** Spaced repetition mastery system: 3 checkpoint dates on MasteryScore (CP1, CP2 after 1+ calendar day, CP3 after 3+ calendar days after CP2). `isMastered` = score ≥ 0.75 + all 3 checkpoints (attempt minimum removed — spacing gate replaces it). Minimum 3 attempts before CP1 can advance (`checkpointMinAttempts`). Single-step checkpoint regression on incorrect answer (CP2→CP1, not full reset). Completed gate permanent. Heatmap colors swapped: proficient=gold, mastered=green. Always-on review block (30% of session, min 3, max 10) in every Smart Practice session from completed strings, prioritizes active checkpoint progression. Warmup intro card only after 1+ day away. "Quick Review" label in quiz UI. Fluency focus mode rotation: Full Fretboard → String Deep Dive → Note Hunt → Position Focus (targets weakest areas). Default session length fixed from 7 to 20. BackupPayload v2 with checkpoint dates (backward compat). TelemetryDeck event definitions. SessionInsightEngine pre-tier fix. Phase Roadmap section on Journey tab (collapsible, 5 subviews). Woodshop font sweep (~50 system fonts → tokens, 10 new tokens). Terminology consistency: "mastered"→"proficient" in all phase messages, Phase 2 "All Notes" label, stale info text updated. Phase indicator moved below rig card. PitchDetector warnings cleaned. project.yml stale ref fixed. 23 new tests, 3 pre-existing failures resolved.

**Phase 4 Monetization (4.1–4.14) — COMPLETE.** EntitlementManager (@Observable, StoreKit 2): isPremium, loadProducts, purchase, restorePurchases, checkEntitlement. 3 product IDs (monthly $4.99, annual $29.99, lifetime $49.99). Injected into AppContainer. PaywallView: phase-aware headline, 3 value props, annual/monthly/lifetime cards with StoreKit displayPrice, "Try Free for 14 Days" CTA, legal text, restore, dismiss. Paywall triggers on locked focus modes (SessionSetupView), locked strings 1-3 (SessionSetupView + heatmap), locked frets 13+ (heatmap). Lock icons on locked cells/buttons. Free-tier enforced in QuizViewModel.buildCandidates() (strings 4-6, frets 0-12) and SmartPracticeEngine.sessionStrings. TelemetryDeck SDK (App ID A538B6A2-0A38-4CC8-8522-12AE1AED7EBF) with 7 analytics signals. Sandbox testing verified all gates. "Wireless Audio"→"External Audio". Legal URLs→fretshed.com. Phase gate: Phase 3/4 trigger PaywallView for free users via `requiresPremium(for:)`. Journey phase roadmap shows lock icons on gated phases.

**Test suite:** 452 tests passing (0 failures)

**Session Insight Engine (INS.1–INS.5) — COMPLETE.** SessionInsightEngine: pure algorithmic service generating pedagogically grounded insight cards. 10 insight types (weakString, strongString, hardestNote, tierTransition, consistencyTrend, closeToLevelUp, coldSpot, coverage, sessionDelta, knowledgeShapeMilestone). InsightPhraseLibrary with deterministic phrase cycling. Tier transition detection via pre-session score reverse-computation. Knowledge shape milestones per BaselineLevel (fire-once). Rotation rule (no same type twice), positivity threshold (force positive after 4 negatives), insight fatigue (shed card hidden every 4th session). Insight card wired to QuizView session results (portrait + landscape). Smart Practice CTA on Shed page uses SmartPracticeEngine.peekNextSessionDescription() — message matches actual session. Session length slider restored to Settings > Session Settings. 11 unit tests.

**Smart Practice Redesign (SP.1–SP.6) — COMPLETE.** 6-phase redesign adding a pedagogically grounded learning progression:
- **LearningPhaseManager** (`@Observable`, UserDefaults-persisted): 4-phase progression (Foundation → Connection → Expansion → Fluency) with automatic advancement criteria. `naturalNoteCells()` for per-string natural note lookup.
- **Temporal decay**: `effectiveScore = prior + (rawScore - prior) * exp(-lambda * days)` with durability modifier. Stale positions decay toward prior, prioritized by SmartPracticeEngine.
- **NoteGroupingEngine**: Pure computation struct producing scale fragments, triads, octave pairs, and chord tones with `NoteGroupContext` metadata (key, musical name, interval names).
- **Phase-aware session planning**: SmartPracticeEngine reads LearningPhaseManager to select phase-appropriate focus modes, note targets, and session structure.
- **PhaseInsightLibrary**: ~70 templated messages across 5 categories per phase (musical context, performance, proximity, comeback, encouragement). Variable substitution system. Phase advancement celebrations. 20 unit tests.
- **Phase UI**: Step indicator on Shed CTA (4-step bar), progress/proximity messages, phase context cards on quiz results (advancement celebration, musical context, next session recommendation). `QuizLaunchCoordinator` carries phase context.
- **Heatmap focus indicator**: Cherry-bordered overlay (40% opacity) on MasteryHeatmapView cells matching current learning target. Phase-specific: Foundation = target string naturals, Connection = cross-string naturals, Expansion = all free-tier cells, Fluency = none.
- **Phase transition fixes (SP.7)**: Foundation stuck fix (nil `currentTargetString` auto-recovery via `autoDetectCompletedStrings()`), `{string_name}`/`{fret_start}`/`{fret_end}` placeholder substitution, Shed phase display refresh after quiz, "PHASE 1" → actual phase name on CTA, contradictory insight card override on advancement, phase-skipping prevention (`sessionsInCurrentPhase` minimum 3 for Connection/Expansion), Next Up button target fix (`nextSessionUsesTargetNotes` flag), `phaseDisplayInfo()` race condition fix (made read-only).
- **Phase resequencing & insight accuracy (SP.8)**: Phases 2↔3 swapped: Expansion (sharps/flats, single-string) now Phase 2, Connection (cross-string, all notes) now Phase 3. Learning gate raised to frets 0–12 (`phaseRequiredFretEnd`). Foundation requires all 6 strings (was 3). Phase 2 per-string tracking (`phaseTwoCompletedStrings`, `currentPhaseTwoTargetString`) with grace threshold. v2 migration flag (`learningPhase_v2Migrated`). `chromaticCells()` + `chromaticFragments()` for Phase 2. Diagnostic mode now builds proper full-fretboard session + calls `completeDiagnostic()`. Confirmation mode builds targeted single-string session. `naturalNotes`/`sharpsAndFlats` focus modes now enforce `session.targetStrings` in QuizViewModel. 6 insight accuracy fixes: "best in N" self-inclusion + `>=` tie bug, "best this week" temporal modifier same bug, "every note" coverage claim without verification (now phase-aware: "natural note"/"accidental"/"note"), "plateau" on 80%+ accuracy, "barely needs to test" at 70%, hardcoded fret range "0–7". Next Up session consistency: pre-built session stashed at peek time, `onNextSession` closure passes `Session` + `[NoteGroup]` so button launches exactly what's described. Dev tap buttons removed from `micListeningView` (only show via `tapModeView` when toggle is on).
- Test count: 420 (22 new), 3 pre-existing failures.

**Pre-launch UI Polish (SD.15) — COMPLETE.** Settings page fully reorganized: 4 sections (Global Display, Session Settings, Guitar Rig Settings, Developer) + Licenses. Detection & Input section removed (empty after moves). Tempo game mode removed from UI (kept in enum for SwiftData backward compat via `selectableCases`). Chord Progression focus mode hidden from UI (kept for future add-on). Focus modes reordered in 2-column grid. Session length changed to GradientSlider. Slider value labels use cherry accent. Haptic Feedback toggle added to Session Settings. Shed page: streak counter + time-practiced alternating messages. Journey page: section titles/info inside cards, date axis formatting. GradientSlider drag fix. DiagnosticRunnerView in Settings Developer section.

**UI Polish & Icons (SD.16) — COMPLETE.** Settings section reordering (Guitar Rig Settings moved up, Session Settings moved down). TestDataSeeder rewrite with session variety. SingleStringIcon SF Symbol replacement. Focus mode color coding. Onboarding skip button removal. tapModeEnabled default fix (false). Metronome volume boost (0.3→0.6). CalibrationView cleanup (removed redundant background/padding).

**Copy Review (SD.17) — COMPLETE.** Comprehensive copy review across all views with "knowledgeable guitar teacher" tone. ~30 copy changes: onboarding, calibration, quiz alerts, session summary, progress tab, settings info sheets, session setup. Removed Circle of Fourths/Fifths and Prioritize Weak Spots from Focus Mode info sheet (deferred features). Added duplicate filter menu to Recent Sessions header on Journey page.

**Pre-Phase 4 Codebase Review (Mar 2026) — COMPLETE.** 6-pass review (architecture, SwiftData, audio pipeline, view layer, App Store risks, code hygiene) produced 28 findings. 6-batch fix plan executed: (B1) Removed 4 dead UserSettings properties + fixed BackupPayload sessionTimeLimitSeconds data loss; (B2) Replaced 3 force-unwraps with safe guards; (B3) os_unfair_lock for Goertzel tracker, I/O buffer sample rate fix 44100→48000, stale TapProcessingState fix on route change; (B4) OSLog error logging on 15+ silent try? mutations; (B5) 44 new tests (SmartPracticeEngine 12, BackupManager 14, CalibrationEngine 18); (B6) Deleted DecayStabilizer + NotificationScheduler, removed ObservableObject from AppContainer, extracted DateFormatter. Test count: 259→286.

**Audio Calibration System (F22) — IMPLEMENTED.** Full calibration flow: silence measurement → 6-string test → profile saved to SwiftData. Quiz launch gated on calibration. Do This First card with action buttons. Settings > Audio Setup with trim sliders. PitchDetector pre-seeded from calibration profile.

**Multi-Profile Calibration (F38) — IMPLEMENTED.** Multiple named calibration profiles per guitar. GuitarType enum (electric/acoustic/classical). Post-calibration naming flow (name + guitar type picker). Settings profile list with context menu (set active, rename, re-calibrate, delete) and swipe actions. Active profile used for quiz detection. Session stamps calibrationProfileID. Practice tab shows active profile name. Backup/restore handles multiple profiles with v1 backward compatibility. Upgrade path auto-names existing profile "Guitar 1".

**Pitch Detection Enhancements (F23) — IMPLEMENTED.** Five improvements to reduce false detections: (1) Spectral flatness gate rejects broadband string slide noise; (2) Consecutive frame gate requires 3 frames of same note; (3) HPF lowered to 60 Hz for better low-string fundamental capture; (4) String-aware frequency constraints narrow detection to target string's Hz range during quiz; (5) HPS octave verification cross-checks YIN with Harmonic Product Spectrum for low-string octave correction.

**DSP Enhancements (F24) — IMPLEMENTED.** Two signal processing improvements: (1) Low-frequency emphasis — input-source-aware 1st-order IIR low-shelf boost below ~250 Hz, compensates MEMS mic roll-off on wound strings (+6 dB built-in mic, +3.5 dB wired headset, off for USB); (2) Adaptive spectral subtraction — captures running noise spectrum estimate (EMA, alpha=0.05) during gate-closed silence periods, subtracts 1.5× over-subtracted noise from power spectrum with spectral flooring before YIN analysis, extends usable detection from "quiet room" to "room with background noise."

**Distortion Tolerance (F25) — IMPLEMENTED.** Three improvements for distorted guitar signals: (1) Crest factor bypass — `vDSP_maxmgv/vDSP_rmsqv` computes peak/RMS ratio; crest < 2.0 indicates clipping (distortion pedal), bypasses flatness gate; (2) Input-source-aware flatness threshold — USB interface relaxed to 0.50 (vs 0.35 for mic/headset) since distortion pedals are only relevant through interfaces; (3) Harmonic spacing regularity — sums power at first 10 integer multiples of HPS fundamental (±1 bin), divides by total power; ratio > 0.3 indicates tonal signal (even if spectrally flat from distortion), bypasses flatness gate. Three-way tonal signal check: `crestFactor < 2.0 || harmonicReg > 0.3 || flatness < threshold`.

**Tuner Sustain Hysteresis (F29) — IMPLEMENTED.** Fixes 12th-fret sustain dropout where the tuner needle drops while the note is still ringing. Three-layer approach: (1) `sustainMode` flag on PitchDetector — TunerView sets true, QuizView leaves false (default); (2) Tap floor lowered to 60% of confidenceThreshold in sustain mode (0.51 vs 0.85) to pass decay-phase frames; (3) Consumer-side confidence hysteresis — once a note is established (consecutive gate met), accepts confidence >= 0.65 to extend sustain; hold window doubled to 500ms. TunerView onChange split into two handlers: detectedNote (resets displayCents on nil→some) and centsDeviation (amplitude-aware EMA only while note active). Quiz behavior is byte-for-byte identical — sustainMode defaults to false, tap floor and hysteresis are both gated.

**Session Data Backup & Restore (F30) — IMPLEMENTED.** JSON export/import in Settings > Data Management. BackupPayload Codable structs decoupled from SwiftData models. BackupManager handles export to Documents directory and import with security-scoped resource access. Files visible in iOS Files app via UIFileSharingEnabled. Updated for multi-profile: exports/imports all calibration profiles with v1 backward compatibility.

**Crash Fix (C1) — FIXED.** PitchDetector crash on infinite/NaN Double→Int conversion. Root cause: YIN parabolic interpolation produces `interpolatedTau ≤ 0` when `bestTau=1`, making `sampleRate / interpolatedTau` infinite. Two-layer fix: guard in `detectPitch()` + defense in `pitchDetectorNoteAndCents()`.

**4-Tier Mastery System (F33) — IMPLEMENTED.** Heatmap and stats now use 4 tiers: Struggling (red, <50%), Learning (amber, 50–89%), Proficient (green, 90%+ but <15 attempts), Mastered (gold, 90%+ AND ≥15 attempts). MasteryLevel enum updated with `from(score:isMastered:)`. HeatmapLegend shows per-tier cell counts. "Cells Mastered" stat uses `visibleMasteredCells()` to match heatmap fret-walk (accounts for octave repeats).

**Journey Tab Enhancements (F34–F36) — IMPLEMENTED.** (F34) Time Practiced metric in Overall Results, responsive to filters. (F35) "Today's Sessions" filter in Journey filter menu. (F36) `.onAppear` reload for tab revisit freshness.

**Device Test Polish (D8) — IMPLEMENTED.** MetroDrone DisclosureGroup labels styled with `sectionHeader` + `text` color.

**All BUGLOG items resolved.** All feature ideas (F1–F38) complete. Smart Practice Redesign (SP.1–SP.7) complete.

**Accuracy Assessment 3× Repetition (F37) — IMPLEMENTED.** Each fretboard cell is played 3 times during an accuracy assessment run. Per-cell results stored in `assessmentCellResultsStore`. Mode indicator shows cell + rep progress. Custom assessment results view with headline accuracy %, per-string accuracy bars, consistency tiles (3/3, 2/3, 1/3, 0/3), and quick stats. Portrait + landscape layouts.

**Expert Review Technical Fixes (Feb 2026) — IMPLEMENTED.** 11 code items from expert panel review:
- Design system sweep: ~458 system colors/fonts replaced with Woodshop tokens across 18 files
- Copy improvements: "Detection Sensitivity", "Note Hold Time", "Session saved to Journey", "Back to The Shed"
- Onboarding grammar fixes (comma splice, subject-verb agreement)
- QuizLaunchCoordinator extraction: 9 quiz-related @State vars + launch/repeat logic moved from ContentView to `@Observable QuizLaunchCoordinator` class. Tab enum renamed to `AppTab` (top-level).
- Notification cleanup: removed 3 dead notification declarations (`.showProgressTab`, `.repeatLastSession`, `.dismissQuiz`)
- Session length guidance hint in SessionSetupView
- DSP unit tests for AccelerateYIN (10 tests: silence, harmonic signals, white noise, spectral flatness, harmonic regularity)
- UserSettings snapshot documented as design decision (live reference safe due to fullscreen overlay)
- Backup/restore (F30): JSON export/import of all SwiftData models via Settings > Data Management

**Finalized business model:** Free tier (strings 4–6, frets 0–12, Full Fretboard + Single String modes, audio detection, adaptive, full stats, Phases 1–2 on free strings, Phase 3–4 require premium). Premium ($4.99/mo, $29.99/yr, $49.99 lifetime, 14-day trial, multiple calibration profiles). Analytics: TelemetryDeck. Subtitle: "Learn Every Fretboard Note."

**Shed Redesign (Phase 3.6) — IMPLEMENTED.** Complete redesign of the Practice ("Shed") tab:
- `BaselinePrior.swift`: `BaselineLevel` enum (5 cases) seeds Bayesian mastery priors for new users based on experience level
- `SmartPracticeEngine.swift`: Rotates focus modes (Full Fretboard → Single String → Same Note), targets weakest areas, `weakSpotCount()` for CTA
- `CompactHeatmapView.swift`: Lightweight 6×13 mastery heatmap for Shed page with 3-label legend
- New `FocusMode` cases: `naturalNotes`, `sharpsAndFlats` with filtering in QuizViewModel; `isFreeMode` computed property
- `sessionTimeLimitSeconds` on Session model with countdown timer in QuizViewModel (auto-completes on expiry)
- Onboarding: 4 screens (added baseline selection: "Where are you at?" with 5 options)
- `SessionSetupView`: Half-sheet (`.presentationDetents([.medium, .large])`), chip-based UI, premium lock icons
- `PracticeHomeView`: Complete rewrite — Smart Practice CTA, calibration banner, dynamic presets, timed practice, "Build Custom Session"
- Shed polish (SD.9–SD.14): CTA label fix, removed compact heatmap from Shed, `alternativeSessions()` quick start tiles, "Got Time?" timed picker, onboarding auto-advance after mic permission, sharpsAndFlats note format override, quiz countdown timer pill, branded LaunchScreen.storyboard, Repeat Last session tracking via coordinator, Repeat Last subtitle (focus mode + game mode + time), "Single Note" renamed to "Same Note"

**Design System Sweep (Mar 2026) — COMPLETE.** Replaced all remaining system fonts/colors with DesignSystem tokens across 16 files. Restyled quiz results with Woodshop cards. Added "You Played" card with color-coded note feedback during quiz. Wrapped prompt in card. Session Setup restyled with custom header + full summary card.

**Settings Reorganization (Mar 2026) — COMPLETE.** Removed dead settings (String Selection — never consumed, Set Mastery Threshold — hardcoded in MasteryLevel). Renamed sections: Audio → Detection & Input, Quiz Defaults → Quiz Behavior. Moved Force Built-In Mic to Audio Setup. Renamed "Metronome in Quiz" → "Countdown Tick". Fixed "Default Focus Mode" mislabel → "Default Practice Mode". Gated Developer section behind `#if DEBUG`. Updated all info sheet copy for accuracy.

**Journey Reload Fix (Mar 2026) — FIXED.** Added `needsProgressReload` flag on QuizLaunchCoordinator + `.onChange` in ContentView to explicitly reload ProgressViewModel after quiz ends. Root cause: `.onAppear` unreliable under ZStack overlay architecture.

**Tuner Needle Smoothing (TN1, Mar 2026) — IMPLEMENTED.** Professional-grade tuner improvements: (1) Hop size halved to 512 in sustainMode (~86 Hz update rate vs ~43 Hz); (2) Dead zone removed in sustain mode — every cents value published for maximum responsiveness; (3) HPS frequency cap raised from 700→1200 Hz for reliable 12th-fret detection (E5=659 Hz, B4=494 Hz now well within range); (4) TunerView 5-tier adaptive alpha with ±1 cent near-instant zone (0.95); (5) Spring animation: response 0.25, damping 0.9 (fast, non-bouncy). All changes gated on sustainMode — zero quiz impact.

**Tuner Calibration Pre-seeding (Mar 2026) — FIXED.** TunerView now loads the active calibration profile and pre-seeds `calibratedNoiseFloor` and `calibratedInputSource` on the detector, matching what QuizView does. Without this, the tuner started with default noise floor (0.01) and no low-frequency emphasis for built-in mic.

**Tuner Expert Review (Mar 2026) — COMPLETE.** Comprehensive 6-expert review in `TUNER_REVIEW_REPORT.md`. Top recommendations: (1) reduce I/O buffer to 5ms in tuner mode, (2) replace EMA+Spring double-smoothing with unified physics model, (3) add pitch tracking mode, (4) sub-cent display + sharp/flat labels, (5) intonation comparison mode.

**Tuner Rewrite Complete (T.P1–T.P4, Mar 2026) — COMPLETE.** Full 4-phase professional tuner upgrade:
- T.P1: I/O buffer reduction, sub-cent display, sharp/flat labels, Drop C/D support, BT latency warning
- T.P2: TunerDisplayEngine (spring-damper physics), lightweight tap fast path, tracking mode, cents-space filtering
- T.P2.5: Goertzel hybrid tracker (magnitude-based 3-bin parabolic interpolation, onset suppression, decay detection), thread-safe NSLock integration, TunerDiagnosticView (#if DEBUG), input source auto-detection in PitchDetector.start(), 17 GoertzelTracker unit tests. Phase tracking removed (unreliable for real guitar signals).
- T.P3: TuningState hysteresis state machine (noSignal→outOfRange→approaching→inTune→settled with hysteresis thresholds), settled readout (enlarged "IN TUNE" with glow), background color wash (green overlay when in tune), string indicator pill (nearest open string badge), responsive dial (tick labels at ±50/±25/0, state-aware needle color red→amber→green, green zone glow), auto-hide level bar
- T.P4: Adaptive update rate (absorbed into T.P2/T.P2.5/T.P3 — hop size, gain scheduling, hysteresis)
- Post-launch: Sweetened tuning offsets, intonation comparison mode (6.6), ghost needle pitch rate predictor (6.7), phase-based Goertzel tracking (if magnitude proves insufficient)

### Tuner Architecture (Shipping — Goertzel Hybrid)

**Pipeline:** YIN identifies the note → Goertzel magnitude (3-bin parabolic interpolation) tracks cents deviation from target frequency. This is the shipping architecture.

**Why Goertzel replaced YIN for cents tracking:** YIN's autocorrelation degrades during note decay at low SNR, producing systematic flat-ward bias of 12–35 cents. No consumer-level filtering (EMA, median, decay stabilizer) can fix this — the bias is algorithmic. An algorithm switch to Goertzel was required.

**Phase A changes (stay permanently):** Reverted the tuner "fast path" (was skipping crest factor + harmonic regularity gates), raised confidence floor to 0.765 (0.85 × 0.90), raised consumer hysteresis to 0.72. These protect YIN acquisition quality — Goertzel depends on YIN correctly identifying the note before taking over.

**Sample rate fix:** Goertzel originally used hardcoded `sampleRate: 44100` instead of the actual hardware sample rate (`tapSampleRate`, which is 48000 on modern iPhones). This was the final fix that brought accuracy to ±1–3 cents.

**Measured accuracy (device-tested Mar 2026):**
- USB interface: sub-cent spread, ±1.5¢ mean accuracy across all 6 strings
- Built-in mic: ±1¢ on plain strings (B, high E), ±5¢ on low wound strings (MEMS roll-off limitation at low frequencies)

**Phase tracking status:** Disabled. Phase-based instantaneous frequency estimation was implemented and tested but produced 0% usable frames on real guitar signals (98% fell back to magnitude). Root cause: guitar signals have too much phase noise at 512-sample hop sizes. Deferred to post-launch if magnitude proves insufficient.

**Next task:** Phase 4 (Monetization).

**Quiz Presentation Architecture (current — ZStack overlay + QuizLaunchCoordinator):**
- `QuizLaunchCoordinator` (`@MainActor @Observable`): owns `selectedTab`, `activeQuizVM`, `showSetup`, `showCalibration*`, `gatedQuizVM`, `pendingTapMode`, `tapModeWasForced`, `pendingQuizVM`
- `ContentView` holds `@State private var quiz = QuizLaunchCoordinator()`, uses `@Bindable` for bindings
- Quiz is a ZStack overlay ABOVE the TabView — no NavigationStack push, no navigation path
- `launchQuiz(vm:)` lives on the coordinator — sets `selectedTab = .practice` + `activeQuizVM = vm`
- `SessionSummaryView` has `onDone / onRepeat: (() -> Void)?` properties; buttons call closures directly — NO NotificationCenter
- ContentView `onReceive` handlers retained only for `.launchQuiz` (from PracticeHomeView) and `.showPracticeTab` (from ProgressTabView empty state)
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

4. **Update BUGLOG.md** — Log any new features (F#) or bug fixes (section-appropriate) implemented this session to both the Feature Ideas & Enhancements table and the Fixed Bugs table. This should be done as changes are made, not just at session end.

5. **Update CLAUDE.md** — If any architectural decisions were made, features implemented, or bugs fixed, update the Current Status section and any relevant sections.

6. **Stage and review changes**
   ```bash
   git status
   git diff --stat
   ```
   Show the user what will be committed. Stage specific files by name (avoid `git add -A` which can accidentally include sensitive files like .env or credentials). Wait for confirmation if the diff is large.

7. **Commit with a descriptive message**
   ```bash
   git commit -m "[Task X.Y] Brief description of what was done"
   ```
   Use the task number from ROADMAP.md if applicable. For multi-task sessions, use multiple commits or a summary message.

8. **Push to remote**
   ```bash
   git push
   ```

9. **Print a session summary** — A brief recap of:
   - What was accomplished
   - What tasks are now complete
   - What the next task is (per ROADMAP.md)

10. **Run sync check** — Scan the Sync Ledger in CLAUDE.md and ROADMAP.md.
    - **Outbound:** If there are any 🔲 Pending outbound items, generate a sync report and a paste-ready prompt for Claude.ai.
    - **Inbound:** If there are any 🔲 Pending inbound items that weren't addressed this session, flag them for the next session.
    - **Strategy flag:** If strategy-relevant changes were made (e.g., business model decisions, positioning updates, new architecture decisions), log them as 🔲 Pending outbound in the Sync Ledger so Claude.ai can absorb them next session.

11. **Generate John's explicit action list** — Always end every session with this block, even if nothing is needed:

    ```
    📋 WHAT YOU NEED TO DO:

    UPLOAD TO CLAUDE.AI PROJECT (replace existing):
    - [list changed files: CLAUDE.md, ROADMAP.md, BUGLOG.md — or "nothing"]

    PASTE INTO CLAUDE.AI NEXT SESSION (if needed):
    - [paste-ready summary of outbound sync items, or "nothing"]

    NOTHING ELSE NEEDED.
    ```

    > **Rule:** Never leave a session without generating this block. John should never have to guess what to do or which files to upload.

12. **Update "What Did I Learn.md"** — Add up to 5 process lessons from this session (not technical details — lessons about the development process, using AI tools, project management, etc.). Keep it conversational. Then rewrite the executive summary at the top to reflect cumulative learnings across all sessions.

---

## Known Issues (from BUGLOG.md)
All device-testing bugs are resolved. All feature ideas (F1–F36) are complete.

---

## Reference Documents (in Claude.ai Project)
- `FretShed_Competitive_Analysis.md` — Full competitive landscape analysis with feature matrix and revised positioning (Feb 2026)
- `TEAM_OF_EXPERTS.md` — 20 expert personas in two teams. Technical Team: Sean Whitfield (SwiftUI), Darren Lowe (DSP), Uma Chen (UX), Gavin Fretwell (guitar pedagogy), Mona Prescott (monetization), Quinn Ashford (QA), Cora Langston (copy), Parker Langdon (privacy), Lars Engström (launch), Ada Xiong (accessibility). Content & Strategy Team: Peter Graves (pedagogy), Theo Marsh (theory), Leo Sandoval (learning science), Irene Novak (instructional design), Trent Holloway (teaching), Fiona Beckett (fretboard), Carmen Reeves (content marketing), Grant Ellison (guitar community), Mason Albright (memory), Bianca Torres (biomechanics).
- `CLAUDE_STRATEGY.md` — Strategy & content guide (Claude.ai's domain — read only from Claude Code)
- `ROADMAP_STRATEGY.md` — Strategy & content task tracker (Claude.ai's domain — read only from Claude Code)
- `HOW_IT_WORKS.md` — How pitch detection, audio calibration, and adaptive learning work (plain language)

## File Ownership Protocol
| File | Owned by | Other interface |
|---|---|---|
| `CLAUDE.md` | Claude Code | Claude.ai reads, never edits |
| `CLAUDE_STRATEGY.md` | Claude.ai | Claude Code reads, never edits |
| `ROADMAP.md` | Claude Code | Claude.ai reads, never edits |
| `ROADMAP_STRATEGY.md` | Claude.ai | Claude Code reads, never edits |
| `TEAM_OF_EXPERTS.md` | Either (rarely changes) | Both read, coordinate edits |

---

## Action Items from Competitive Analysis
- [x] Update onboarding subtitle in code: "The guitar trainer that actually gets your notes right." (done in OnboardingView.swift)
- [ ] When writing App Store description (Task 5.12): use revised positioning from competitive analysis — lead with calibration + adaptive learning, NOT "only app that listens"
- [ ] When creating App Store screenshots (Task 5.2): feature the calibration flow as a key differentiator

---

## Sync Ledger

> See `SYNC_PROTOCOL.md` for how this works. Claude Code owns this file; Claude.ai reads only.

### Outbound (changes Claude.ai needs to know about)
| Date | What Changed | Target | Status |
|---|---|---|---|
| 2026-03-10 | Pre-Phase 4 codebase review complete (6 batches). Test count now 286. Dead code removed (DecayStabilizer, NotificationScheduler). AppContainer no longer ObservableObject. Next task: Phase 4.2+. ROADMAP_STRATEGY.md may need S6 section update per Claude.ai. | ROADMAP_STRATEGY.md, CLAUDE_STRATEGY.md | ✅ Synced |
| 2026-03-15 | Smart Practice Redesign complete (SP.1–SP.7). 4-phase learning progression (Foundation→Connection→Expansion→Fluency), temporal decay, note grouping engine, phase-aware messaging (~70 templates), heatmap focus indicator. SP.7: 8 phase transition bug fixes (phase-skipping prevention, placeholder substitution, contradictory messaging, race conditions). Session Insight Engine (INS.1–INS.5) also complete. Test count now 398. Next task: Phase 4 (Monetization). | ROADMAP_STRATEGY.md, CLAUDE_STRATEGY.md | ✅ Synced |
| 2026-03-16 | SP.8 Phase Resequencing + Insight Accuracy (expert review findings). Phases resequenced: Foundation→Expansion→Connection→Fluency. Fret range 0-12, all 6 strings required. All free-tier restrictions removed (unrestricted until Phase 4). 7 insight false-claim bugs fixed + contradiction detection test infra (5 scenario tests). Musical context now phase-aware (chromaticFragment GroupType). Stale Shed phase refresh, weakest-string untried-cell counting, Next Up session consistency, quiz UI cleanup (merged level bar), TunerView cross-tab alert fix. Test count 425. Next task: Phase 4. | ROADMAP_STRATEGY.md, CLAUDE_STRATEGY.md | ✅ Synced |
| 2026-03-18 | Spacing Gate & Smart Review system (SG.1–SG.9). Spaced repetition mastery: 3 checkpoints across 5+ days, single-step regression, completed gate permanent. Always-on review block (30%). Fluency rotation (4 modes). Heatmap: proficient=gold, mastered=green. Phase Roadmap on Journey tab. Woodshop font sweep (50+ fixes). Terminology consistency (mastered→proficient in phase messages). Default session length=20. Test count 448 (0 failures). Next: Phase 4. | ROADMAP_STRATEGY.md, CLAUDE_STRATEGY.md | ✅ Synced |

### Inbound (changes requested by Claude.ai)
| Date | Change Requested | Source | Status |
|---|---|---|---|
| | | | |
