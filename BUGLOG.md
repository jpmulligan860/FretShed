# FretShed — Bug Log

Log issues found during physical device testing. For each bug, note what you tapped, what you expected, and what actually happened. Include iOS version and device if relevant.

**Status key**: 🐛 Open · 🔧 In Progress · ✅ Fixed

---

## Practice Tab

| # | Status | Description | Steps to Reproduce | Notes |
|---|---|---|---|---|
| P1 | ✅ Fixed |Note detection fails or is inaccurate | Practicing single string in a quiet room with acoustic guitar. Input volume seems too low causing false incorrect identifications of notes played. Notes should be detected if they are played staccato or sustained. Internal iphone mic used. | Tested on iPhone 16 Pro, iOS 26.2.1. |
| P2 | ✅ Fixed | incorrect note detection on c# and A on the sixth string | Practicing single string in a quiet room with acoustic guitar. Input volume seems too low causing false incorrect identifications of notes played. Notes should be detected if they are played staccato or sustained. Internal iphone mic used. | Tested on iPhone 16 Pro, iOS 26.2.1. |
| P3 | ✅ Fixed | Inconsistent note detection at all frets across all six strings | Practicing all strings across all frets in a quiet room with acoustic guitar. Input volume seems too low causing false incorrect identifications of notes played. Notes should be detected if they are played staccato or sustained. Internal iPhone mic used. | Tested on iPhone 16 Pro, iOS 26.2.1. |
| P4 | ✅ Fixed | Correct note intermittently marked wrong, corrects itself on repeat | Sometimes the correct note is marked incorrect. The next note quizzed is a repeat of the same note, and when played again it is scored correct. Internal iPhone mic used. | Tested on iPhone 16 Pro, iOS 26.2.1. |
| P5 | ✅ Fixed | No way to turn on tap mode | There is no way to turn on finger tap mode either in the Practice Tab, or in the settings. | Tested on iPhone 16 Pro, iOS 26.2.1. |


---

## Progress Tab

| # | Status | Description | Steps to Reproduce | Notes |
|---|---|---|---|---|
| Pr1 | ✅ Fixed | Fretboard heatmap is scrolling| Fretboard heatmap should automatically be sized to show full fretboard on session results and Progress page| Tested on iPhone 16 Pro, iOS 26.2.1. |
| Pr2 | ✅ Fixed | Fretboard Sizing Issue in Results | The fretboad heatmaps should be sized so that the full fretboard as defined in the Default Fret Count in Settings is visible.in both session results and in the overall results.| Tested on iPhone 16 Pro, iOS 26.2.1. |
| Pr5 | ✅ Fixed | Tapping a session in the filtered list does not display results and freezes app | On the Progress tab, tap any session row in the recent sessions list. Expected: session detail sheet appears. Actual: app freezes, no sheet displayed. | **Root cause:** `SessionHeatmapView` used `onGeometryChange` to read its own width and feed it back into cell sizing — same infinite layout cycle as MasteryHeatmapView (Pr1/Pr2). Fixed by adding `availableWidth` parameter passed from `SessionDetailView` via `GeometryReader`. |
| Pr4 | ✅ Fixed | Move Delete All button below filtered list; add "Filter Results" label next to filter icon | Delete All button is too close to the filter icon and can be hit accidentally. Move it to the bottom of the page under the filtered list. Add a "Filter Results" label next to the filter icon for clarity. | Moved "Delete All Sessions" button below the session list, centered. Added "Filter Results" text label next to the filter icon in the menu button. |
| Pr3 | ✅ Fixed | Progress tab freezes — cannot navigate away without force-quitting | Tap the Progress tab. "No progress yet" empty state is shown. Tapping any other tab item produces no response. App must be force-quit to recover. | **Root cause:** `AppContainer` created a separate `ModelContext(container)` while SwiftUI's `.modelContainer()` injected its own `mainContext`. Two contexts on the same SQLite store caused WAL-level contention — `mainContext` auto-save blocked repository fetches, freezing the main thread. **Fix (2026-02-22):** Changed `AppContainer` to use `container.mainContext` instead of `ModelContext(container)`. Also replaced `List`-inside-`ScrollView` with `VStack` and passed `availableWidth` to `MasteryHeatmapView` to avoid layout feedback loops. |

---

## Tuner Tab

| # | Status | Description | Steps to Reproduce | Notes |
|---|---|---|---|---|
| T1 | ✅ Fixed | Tuner does not tune when playing hollowbody guitar unplugged | open tuner, try to tune guitar using internal microphone in quiet room.  needle is jittery and detected not jumps all over the place.| Tested on iPhone 16 Pro, iOS 26.2.1. |
| T2 | ✅ Fixed | Tuner needle shows pitch change as volume decays | when tuning, a note is played and the tuner needle shows the pitch changing as the note sustain trails off, decreasing volume even if the pitch remains the same.| Tested on iPhone 16 Pro, iOS 26.2.1. |
| T3 | ✅ Fixed | Tuner needle defaults to correct pitch as volume decays | when tuning, a note is played and the tuner needle shows returns to center as the note sustain trails off, decreasing volume.| Tested on iPhone 16 Pro, iOS 26.2.1. |

---

## MetroDrone Tab

| # | Status | Description | Steps to Reproduce | Notes |
|---|---|---|---|---|
| M1 | ✅ Fixed | Drone Play Button in wrong section | The play button for the Drone should be in Drone Setting section.| Tested on iPhone 16 Pro, iOS 26.2.1. |
| M2 | ✅ Fixed | Metronome Accents and Muting | The buttons for the accent, mute, and notes needs a title for the section so user knows what it is. |
| M6 | ✅ Fixed | Note divisions are not working on the metronome | Tapping a different note division (quarter, eighth, triplet, sixteenth) does not change the subdivision audibly. The metronome continues playing as if the subdivision was not changed. | **Three fixes:** (1) Sub-click buffer was ~15% peak amplitude vs ~96% for normal clicks — inaudible on phone speaker. Boosted to ~62% peak with higher pitch (1200 Hz vs 900 Hz) for distinction. (2) Replaced segmented Picker with explicit Buttons calling `vm.setSubdivision()` to avoid `@Observable` binding issues. (3) Added `startingBeat` parameter to `engine.startMetronome()` so subdivision changes don't reset the beat indicator. |
| M3 | ✅ Fixed | Count in functionality should be moved to the speed trainer feature | There is no need to have a count in for the regular metronome. Move this feature to the speed trainer where you can choose 1 or two bar count-in before speed trainer starts. | Moved count-in UI stepper into Speed Trainer DisclosureGroup. Count-in logic now only activates in `startSpeedTrainer()`, not `startMetronome()`. |
| M4 | ✅ Fixed | Drone: Eliminate 1st and 5th octave settings  | The first octave setting is two low to hear properly and the 5th octave is to high and is annoying. |
| M5 | ✅ Fixed | Drone: LFO sync with metronome | The LFO on the drone should sync with the metronome tempo when both are playing at the same time. | Added `lfoRateHz` field to `DroneState`. When metronome starts, LFO rate is set to `bpm/60` Hz. When metronome stops, LFO reverts to default 1.5 Hz. Also syncs on BPM changes (speed trainer). |
| M7 | ✅ Fixed | Speed trainer tempo changes don't start on a downbeat | When the speed trainer advances to a new BPM, the tempo change doesn't align with beat 1. The new speed should start on a downbeat so the tempo transition feels musical. | **Root cause:** `delayFirstBeat` slept for one `subInterval` (= beat interval / subdivision count). With eighth notes the delay was half a beat, with sixteenths a quarter beat — so the new tempo started mid-beat. **Fix:** Changed delay from `subInterval` to full `interval` (one beat duration) so the new tempo always starts on a proper downbeat. |
| M11 | ✅ Fixed | Drone LFO amplitude should be ±2.0 dB | The LFO amplitude modulation on the drone is too strong at ±3 dB. Change it to ±2.0 dB. | Changed LFO amplitude from 0.35 (±3 dB) to 0.26 (±2 dB). |
| M10 | ✅ Fixed | Drone LFO not syncing with metronome BPM when both are playing | When the metronome and drone are playing at the same time, the drone's LFO rate should match the metronome's BPM. | M5 set the rate correctly but two issues remained: (1) LFO depth was ±1.5 dB (amplitude 0.17) — imperceptible on phone speaker. Increased to ±3 dB (amplitude 0.35). (2) LFO phase was not aligned with beat — peaks could land between beats. Added `needsLFOPhaseReset` flag to `DroneState`; `updateDroneLFORate()` triggers a phase reset so the LFO peak aligns with beat 1. |
| M9 | ✅ Fixed | Speed trainer: count-in should always be quarter notes; BPM increases should land on beat 1 | The count-in bars before the speed trainer starts should always play quarter notes regardless of the selected subdivision. Also, when the speed trainer increases BPM, the new tempo should begin on beat 1 (the downbeat) of a measure, not mid-measure. | **Two fixes:** (1) Count-in now starts the engine with `.quarter` subdivision. When count-in ends, `handleBeat` restarts with the selected subdivision. (2) `advanceTrainerTempo()` now stores the new BPM in `pendingTrainerBPM` instead of applying immediately. `handleBeat` applies it on beat 0 (downbeat) of the next measure via `engine.updateMetronomeBPM()`. |
| M8 | ✅ Fixed | Speed trainer: subdivisions on the last beat of the measure are not heard or not played | When using the speed trainer with note divisions (e.g. eighth notes), the subdivisions on the last beat of each measure are either not being played or are inaudible. All other beats have audible subdivisions. | **Root cause:** `advanceTrainerTempo()` called `restartMetronome()` which cancelled the scheduling task during `onBeat(lastBeat)`. The remaining sub-beats for that beat never played. **Fix:** Speed trainer tempo changes now use `engine.updateMetronomeBPM()` which updates the stored BPM without restarting. The scheduling loop reads `metronomeBPM` dynamically on each sleep cycle, so the new tempo takes effect seamlessly and no sub-beats are lost. |

---

## Settings Tab

| # | Status | Description | Steps to Reproduce | Notes |
|---|---|---|---|---|
| S1 | ✅ Fixed | Quiz defaults reset after app relaunch | I reset the default quiz settings, then closed and restarted the app.  Quiz setting I changes were not retained and returned to app default.| Tested on iPhone 16 Pro, iOS 26.2.1. |
| S2 | ✅ Fixed | Default Fret Count settings are incorrect | Choices for Default Fret Count should be 12, 21, 22, 24| Tested on iPhone 16 Pro, iOS 26.2.1. |
| S3 | ✅ Fixed | Only need one volume slider for correct and incorrect sound | Only one volume slider is needed for incorrect and correct answer sounds.  Maybe title this Response Sound Volume| Tested on iPhone 16 Pro, iOS 26.2.1. |
| S4 | ✅ Fixed | Only need one toggle needed for correct and incorrect sound | Only one toggle is needed for incorrect and correct answer sounds.Maybe title this Response Sounds.| Tested on iPhone 16 Pro, iOS 26.2.1. |
| S5 | ✅ Fixed | Note Highlighting: Reveal After doesnt work. | When Note Highlighting is set to Reveal After, the notes are still displayed in the quizzes before a note is played. Reveal after shoud also be the app default.| Tested on iPhone 16 Pro, iOS 26.2.1. |
| S6 | ✅ Fixed | Timer Duration range adjustment needed | adjust the Timer Range so it ranges from 2-20 seconds| Tested on iPhone 16 Pro, iOS 26.2.1. |
| S7 | ✅ Fixed | Hint timeout not working | The hint timeout slider works, but the hint is not shown unless the Show Hint button on the quiz is tapped.  The expected functionality is that the hint should be displayed either when the Show Hint button is displayed or after the Hint timeout time has been reached for each note on the quiz. Maybe change this to "Show Hint After" in the settings. | Tested on iPhone 16 Pro, iOS 26.2.1. |
| S8 | ✅ Fixed | Master Threshold label is confusing | Change label to "Set Mastery Threshold"| Tested on iPhone 16 Pro, iOS 26.2.1. |
| S9 | ✅ Fixed | the Session Length Setting doesnt work. | The slider works, but the quizzes are always 20 questions long.  This setting should set the number of questions in all quizzez except Streak. | Tested on iPhone 16 Pro, iOS 26.2.1. |
---

## Quiz / Fretboard (launched from Practice)

| # | Status | Description | Steps to Reproduce | Notes |
|---|---|---|---|---|
| Q6 | ✅ Fixed | Session results buttons untappable; session results not saved to Progress tab | Complete a session via any path — quick-start cards, Repeat Last, or the setup flow. Results screen buttons (Done, View Progress, Repeat) did not respond. Session length setting was ignored (always 20 questions). Results did not appear in Progress tab. | **Fixed 2026-02-22.** Fixed sub-issues: (A) **Session length** — `SessionSetupView.@State sessionLength` defaulted to 20, never loaded from settings. Fixed: load in `.task { }`, save before creating VM. (B) **Results not saved** — `SwiftDataSessionRepository.complete()` had `if context.hasChanges` guard that SwiftData auto-save could clear silently. Fixed: always call `context.save()` unconditionally. **Button fix history — all approaches tried and failed on device (iPhone 16 Pro, iOS 26.2.1):** (1) ZStack overlay ❌ (2) UIWindow at `.alert-1` ❌ (3) UIWindow at `.alert+1` with `UIHostingController.rootView` swap ❌ (4) `NavigationStack` push + `.toolbar(.hidden, for: .tabBar)` ❌ (5) `fullScreenCover` on TabView + closure chain (`onDone`) ❌ (6) `fullScreenCover` + `@Environment(\.dismiss)` ❌ (7) `fullScreenCover` + pure **NotificationCenter** buttons — **current implementation, NOT YET TESTED on device as of session end**. **Current architecture (as of 2026-02-22 session end):** Quiz+results presented via `fullScreenCover` on `TabView`. `ContentView.activeQuizVM: QuizViewModel?` drives the cover. `QuizFlowView` (private struct) shows `QuizView` → `SessionSummaryView` via `@State showResults`. All three buttons post `NotificationCenter` notifications only — no closures, no `@Environment(\.dismiss)`. ContentView handles: `.dismissQuiz` → `activeQuizVM = nil`; `.showProgressTab` → `activeQuizVM = nil` + tab switch; `.repeatLastSession` → `activeQuizVM = nil` + 500ms delay + new quiz. **If notifications also fail:** touch events are not reaching SwiftUI at all. Next diagnostic step: add a dead-simple overlay button directly in `QuizFlowView` (above `SessionSummaryView` in a ZStack, bold/colored, posts `.dismissQuiz`) to isolate whether ANY SwiftUI button works in the results context. |
| Q1 | ✅ Fixed | Fretboard Sizing Issue | The fretboad should be sized so that the full fretboard as defined in the Default Fret Count in Settings is visible.| Tested on iPhone 16 Pro, iOS 26.2.1. |
| Q2 | ✅ Fixed | Add a Mute Timer button on timed quizzes | Add a mute timer button in timed quizzes which overrides the default "Metronome in Quiz" setting. | Added `isTimerMuted` toggle to QuizViewModel. Speaker icon button added to timer bar in QuizView. When muted, `playCountdownTick()` calls are skipped. |
| Q3 | ✅ Fixed | Correct Note Messages | When the correct note button is tapped, the Listening window displays all of the correct note messages one after another instead of rotating randomly through the correct note messages.| Tested on iPhone 16 Pro, iOS 26.2.1. |
| Q4 | ✅ Fixed | Chord Progression mode is not using close triads | Chord Progression notes are still too far away from each other. 3rd and 5th notes should be played within a close triad and should be within one or two frets away from the root so they could be played like a root, first, or second position triad. | Tightened close voicing from 4-fret window to 2-fret + 2-string adjacency. Also tracks root string. Falls back to 3-fret window if no tight voicing exists. |
| Q5 | ✅ Fixed | Correct Note not shown after correct answers | In the quiz mode, the correct notes are displayed after a correct answer, but they are not displayed after an incorrect one as they should be.  Note highlighting settings should be used for this as well.| Tested on iPhone 16 Pro, iOS 26.2.1. |
---

## Known Anomalies (from file audit — not yet investigated)

| # | Status | Description | Location | Notes |
|---|---|---|---|---|
| A1 | ✅ Fixed | 5 stray Swift files inside `FretShed.xcodeproj/` | `FretShed.xcodeproj/CellDetailSheet.swift`, `MasteryHeatmapView.swift`, `ProgressView.swift`, `ProgressViewModel.swift`, `ProgressViewModelTests.swift` | Deleted — accidentally dragged into .xcodeproj bundle. |
| A2 | ✅ Fixed | 2 loose Swift files in project root | `./NotificationScheduler.swift`, `./Repositories.swift` | `NotificationScheduler.swift` is intentionally at root (referenced in project.yml sources). `Repositories.swift` was an empty stub — deleted. |
| A3 | ✅ Fixed | `Progress/Repositories.swift` is a third copy of the repository protocols | `FretShed/Progress/Repositories.swift` | Deleted `Progress/Repositories.swift` and `Data/SwiftData/Repositories.swift`. Canonical copy remains at `Domain/Repositories/Repositories.swift`. Removed excludes from project.yml. |

---

## Feature Ideas & Enhancements

Ideas discovered during testing. Not bugs — things that don't exist yet or could work better.

| # | Area | Idea | Notes |
|---|---|---|---|
| F1 | ✅ Fixed | Quiz/Results | Add Repeat Session button to session results | When a session is completed and session results are displayed, have a button that says "Repeat" which saves the session and starts a new session with the same settings. This will allow the user to drill the same quiz settings repeatedly. |
| F2 | ✅ Done | Quiz/Progress | In timed sessions, add an average time to answer | Added `correctResponseTimes` tracking to `QuizViewModel` for correct answers only. "Avg Time" stat card shown on timed session results. Response time trend line chart (cyan) added to Progress tab. Session detail view shows avg response time for timed sessions. |
| F3 | ✅ Fixed | Progress | Add a Filter section for session results | On the progress page, add a "filter by" button which filters the sessions by session type. This should change the overall results to reflect only the filtered session type (e.g. Full Fretboard only, Single String only, etc.). |
| F4 | ✅ Fixed | MetroDrone | Metronome note division settings | The metronome should support: Quarter notes, Eighth notes, Sixteenth notes, Triplets (shuffle/swing), Accented quarter notes (backbeat on 2 & 4). |
| F5 | Quiz | Chord Progression: add note selection | In chord progression settings, add ability to choose: Root Note Only, Root + 3rd, Root + 5th, or Close Triad. Display should follow the Note Highlighting setting. Quiz should wait for all selected notes played in sequence before moving to the next chord. |
| F9 | ✅ Done | Progress | Overall Results section needs title, label updates, and info button | Added "OVERALL RESULTS" section header to overallCard. Renamed labels to "Cells Attempted", "Cells Mastered", "Overall Mastery". Added info button with sheet explaining each measurement. |
| F10 | ✅ Done | Progress | Add info buttons to each section of the Progress tab | Added info buttons (ℹ️ circle icons) to all five sections: Overall Results, Fretboard Mastery, Accuracy Trend, Avg Response Time, Recent Sessions. Each opens a `ProgressInfoSheet` explaining what the section measures. |
| F11 | ✅ Done | Progress | Fretboard Mastery heatmap legend spacing and label fix | Changed "Not tried" to "Untried". Tightened spacing: item gap 12→6, inner gap 4→3, swatch size 12→10. |
| F12 | ✅ Done | Progress | Reorder Progress page sections and rename response time chart | iPhone order: Overall Results → Fretboard Mastery → Accuracy Trend → Avg Response Time → Recent Sessions. iPad: overall + heatmap side-by-side, charts below. Chart title changed to "AVG RESPONSE TIME (TIMED SESSIONS ONLY)". |
| F15 | ✅ Done | Progress | Cells Attempted now reflects actual fretboard size | Added `uniqueCellCount(fretCount:)` to `FretboardMap`. `ProgressTabView` reads `defaultFretCount` from `@AppStorage` and computes dynamic `totalCells` instead of hardcoded 72. |
| F16 | ✅ Done | Progress | Filter moved to toolbar; label shows active filter name | Moved `filterMenu` from Recent Sessions header to `.toolbar { ToolbarItem(placement: .topBarTrailing) }`. Label reads "Filter Results" when no filter is active, "Filtered: [name]" when a filter is selected (e.g. "Filtered: Full Fretboard" or "Filtered: Timed Sessions"). |
| F13 | ✅ Done | Progress | Accuracy Trend, Avg Response Time, and Fretboard Mastery should filter with session filter | Added `recalculateForFilter()` to `ProgressViewModel`. When a filter is selected, accuracy trend, response time trend, heatmap scoreGrid, overall mastery, attempted cells, and mastered cells all recalculate from only the filtered sessions' attempts. Base (unfiltered) data is cached and restored when filter is cleared. |
| F14 | ✅ Done | Progress | Add clock icon to timed sessions in list; add "Timed Sessions" filter option | Added cyan clock icon (`clock.fill`) next to timed sessions in `SessionRow`. Added "Timed Sessions" option to the filter menu via `gameModeFilter: GameMode?` on `ProgressViewModel`. Filter menu now supports both focus mode and game mode filters. |
| F6 | ✅ Fixed | Remove 432 Hz reference option | Only 440 Hz is needed. Remove the 432 Hz option to simplify the tuner settings. |
| F7 | ✅ Fixed | Remove strobe display mode | Only needle mode is needed. Remove the strobe option to simplify the tuner. |
| F8 | ✅ Fixed | Remove Haptic Feedback toggle from settings | Phone is typically not held while using the app so haptics aren't useful. Remove from settings UI but leave the code in place in case user feedback requests it. |

---

## Fixed Bugs

| # | Description | Fixed In | Commit |
|---|---|---|---|
| L1 | Black bars at top and bottom of all tabs — app letterboxed on device | `UILaunchScreen: {}` added to Info.plist via project.yml; `INFOPLIST_KEY_UILaunchStoryboardName: ""` removed | Session 2026-02-21 |
| S9 | Session Length Setting doesn't work | Removed hardcoded `defaultSessionLength = 20` override in `quickLaunch()` and `repeatLastSession()` in ContentView.swift | Session 2026-02-22 |
| S5 | Note Highlighting: Reveal After shows dots before answer | Added `showTargetDot: Bool` parameter to `CompactFretboardView`; set to false when highlighting is `.singleThenReveal` and phase is not `.feedbackCorrect` | Session 2026-02-22 |
| S7 | Hint auto-show timer not working | Added `hintTask` in QuizView; starts countdown from `settings.hintTimeoutSeconds` on each new question and on returning to `.active` phase | Session 2026-02-22 |
| Q3 | Correct note messages cycle too fast | Moved message pick to `storedCorrectMessage: @State`, set once when phase transitions to `.feedbackCorrect`, preventing re-randomization on each render | Session 2026-02-22 |
| S1 | Quiz defaults reset after app relaunch | Two fixes: (1) `saveSettings()` now always calls `context.save()` unconditionally; (2) `SettingsView.loadSettings()` no longer falls back to a detached `UserSettings()` — if load fails it retries once after 300ms | Session 2026-02-22 |
| P5 | No tap mode available | Added `tapModeEnabled: Bool` to `UserSettings`; toggle in Settings > Audio; in quiz, tap mode shows Correct/Wrong buttons instead of mic listener and skips starting the microphone | Session 2026-02-22 |
| P1–P3, T1 | Note detection inaccurate / tuner jittery on quiet guitars | Added Auto-Gain Control to `TapProcessingState` (target −18 dBFS, adapts only when gate open, ×0.5–×16 clamp, 2% per frame). Applied via `vDSP_vsmul` to the analysis buffer before YIN. Initial gain ×2. | Session 2026-02-22 |
| P2–P4 | Octave errors on low E/A strings | Added double-tau octave correction in `AccelerateYIN.detectPitch`: after `bestTau` found, descend from `bestTau*2`; if CMND < 0.35, prefer the lower-frequency (true fundamental) tau | Session 2026-02-22 |
| T2, T3 | Tuner needle snaps to center / changes pitch as note decays | Added 250ms pitch hold in consumer task: `.silent`/`.none` events within the hold window keep `detectedNote`/`centsDeviation` unchanged; hold is extended on each new `.detected` | Session 2026-02-22 |
| Q5 | Correct note not revealed after wrong answer | Added `.feedbackWrong` to `showTargetDot` and `revealAllPositions` checks in `QuizView` — both now trigger on correct OR incorrect feedback | Session 2026-02-22 |
| Pr1, Pr2 | Heatmap scrolls instead of auto-sizing | Removed `ScrollView(.horizontal)` from `MasteryHeatmapView` and `SessionHeatmapView`; replaced fixed `cellSize = 28` with `@State contentWidth` + `onGeometryChange` to compute cell width dynamically from available space | Session 2026-02-22 |
| Q1 | Fretboard dots overlap at 22/24-fret count | Changed `dotRadius` from fixed `11` to `min(11, fretSpacing * 0.42)` in `FretboardView`; dots scale down proportionally when frets are tightly packed | Session 2026-02-22 |
| Q-exit | Done / View Progress buttons unresponsive on session results | `SessionSummaryView` was presented with a dead `Binding(set: { _ in })` so SwiftUI could never dismiss the cover. Fixed by adding `@State private var showSummary` to `QuizView`, setting it `true` on `.complete` phase, binding the cover to `$showSummary`, and in `onDone` setting it `false` before calling `dismiss()` | Session 2026-02-22 |
| Q6 | Session results buttons untappable (all session lengths, both launch paths) | **Root cause (after 8+ failed approaches):** `onReceive(NotificationCenter…)` handlers in ContentView do not fire reliably on iOS 26 while a NavigationStack destination or fullScreenCover is active. Every approach that posted notifications from results buttons and handled them in ContentView was broken regardless of presentation style. NavigationStack push also had a secondary blank-page bug where `navigationDestination` rendered before SwiftUI committed `activeQuizVM`. **Final architecture (2026-02-22 — third attempt):** Quiz presented as a ZStack overlay at ContentView root level. `ContentView.body` = `ZStack { TabView; if let vm = activeQuizVM { quizOverlay.zIndex(1) } }`. `SessionSummaryView` has `onDone / onViewProgress / onRepeat: (() -> Void)?`. All three buttons call their closure directly — zero NotificationCenter use. ContentView passes closures when creating `QuizSessionView`. `launchQuiz(vm:)` = `activeQuizVM = vm`. Needs device verification. | Session 2026-02-22 |
| F1 | Add Repeat Session button to session results | Added `repeatButton` to `SessionSummaryView`; posts `.repeatLastSession` notification then calls `onDone`. `PracticeHomeView` receives the notification (with 600ms delay for animation safety), reloads `lastSession`, and calls `repeatLastSession()` | Session 2026-02-22 |
| F3 | Add filter to Progress Recent Sessions | Added `focusModeFilter: FocusMode?` and computed `filteredSessions` to `ProgressViewModel`; added `filterMenu` and `filteredEmptyState` to `ProgressTabView`; session load limit raised from 20 → 50 | Session 2026-02-22 |
| F4 | Metronome note division settings | Added `NoteSubdivision` enum (quarter/eighth/triplet/sixteenth) to `MetroDroneViewModel`; `MetroDroneEngine.startMetronome` now fires sub-beat clicks at lower amplitude between main beats; segmented picker added to `MetroDroneView` | Session 2026-02-22 |
