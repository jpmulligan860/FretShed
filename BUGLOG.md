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
| Pr3 | 🔧 In Progress | Progress tab freezes — cannot navigate away without force-quitting | Tap the Progress tab. "No progress yet" empty state is shown. Tapping any other tab item produces no response. App must be force-quit to recover. | Tested on iPhone 16 Pro, iOS 26.2.1. **Root cause hypothesis:** `ProgressIndicatorOverlay` inside `.overlay` extended a full-screen `Color` view into the iOS 26 Liquid Glass tab bar touch region during load. This appears to leave the tab bar's gesture recogniser state corrupted even after the overlay disappears. **Fix (attempt 1, 2026-02-22):** Removed `ignoresSafeArea()` from `Color` in overlay — not sufficient, freeze persisted. **Fix (attempt 2, 2026-02-22):** Removed the full-screen `Color` backdrop entirely from `ProgressIndicatorOverlay`; replaced with a compact `ProgressView + .regularMaterial` badge. Added `.allowsHitTesting(false)` to the overlay call site so no touch anywhere in the loading indicator region can be absorbed, regardless of layout. Needs device verification. |

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
| M3 | 🐛 Open | Count in fuctionality should be moved to the speed trainer feature | There is no need to have a count in for the reqgular metronome.  Move this feature to the speed trainer where you can choose 1 or two bar countin before speed trainer starts.|
| M4 | ✅ Fixed | Drone: Eliminate 1st and 5th octave settings  | The first octave setting is two low to hear properly and the 5th octave is to high and is annoying. |
| M5 | 🐛 Open | Drone: Sync | The lfo on the drone sounds with the tempo used in the metronome is they are both playing at the same time. |

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
| Q2 | 🐛 Open | add a Mute Timer button on timed quizes | add a mute Timer button in timed quizes which overrides the default "Metronome in Quiz" setting.| Tested on iPhone 16 Pro, iOS 26.2.1. |
| Q3 | ✅ Fixed | Correct Note Messages | When the correct note button is tapped, the Listening window displays all of the correct note messages one after another instead of rotating randomly through the correct note messages.| Tested on iPhone 16 Pro, iOS 26.2.1. |
| Q4 | 🐛 Open | Chord Progression mode is not using close triads | Chord Progression notes are still too far away from each other.  3rd and 5th notes should be played within a close triad and should be withing one or two frets away from the route so they could be played like a root, first, or second position triad.| Tested on iPhone 16 Pro, iOS 26.2.1. |
| Q5 | ✅ Fixed | Correct Note not shown after correct answers | In the quiz mode, the correct notes are displayed after a correct answer, but they are not displayed after an incorrect one as they should be.  Note highlighting settings should be used for this as well.| Tested on iPhone 16 Pro, iOS 26.2.1. |
---

## Known Anomalies (from file audit — not yet investigated)

| # | Status | Description | Location | Notes |
|---|---|---|---|---|
| A1 | 🐛 Open | 5 stray Swift files inside `FretShed.xcodeproj/` | `FretShed.xcodeproj/CellDetailSheet.swift`, `MasteryHeatmapView.swift`, `ProgressView.swift`, `ProgressViewModel.swift`, `ProgressViewModelTests.swift` | Likely dragged there accidentally in Xcode. Investigate and move or delete. |
| A2 | 🐛 Open | 2 loose Swift files in project root | `./NotificationScheduler.swift`, `./Repositories.swift` | Not inside any folder group. Need to confirm if they're referenced by the project or are dead code. |
| A3 | 🐛 Open | `Progress/Repositories.swift` is a third copy of the repository protocols | `FretShed/Progress/Repositories.swift` | Already have copies in `Data/SwiftData/` and `Domain/Repositories/`. One source of truth needed. |

---

## Feature Ideas & Enhancements

Ideas discovered during testing. Not bugs — things that don't exist yet or could work better.

| # | Area | Idea | Notes |
|---|---|---|---|
| F1 | ✅ Fixed | Quiz/Results | Add Repeat Session button to session results | When a session is completed and session results are displayed, have a button that says "Repeat" which saves the session and starts a new session with the same settings. This will allow the user to drill the same quiz settings repeatedly. |
| F2 | Quiz/Progress | In timed sessions, add an average time to answer | In quizzes that are timed, add an average time to answer in the results. Add a line chart to the Progress tab that tracks the average time to answer over time. This should only be for timed quizzes and for correct answers only. |
| F3 | ✅ Fixed | Progress | Add a Filter section for session results | On the progress page, add a "filter by" button which filters the sessions by session type. This should change the overall results to reflect only the filtered session type (e.g. Full Fretboard only, Single String only, etc.). |
| F4 | ✅ Fixed | MetroDrone | Metronome note division settings | The metronome should support: Quarter notes, Eighth notes, Sixteenth notes, Triplets (shuffle/swing), Accented quarter notes (backbeat on 2 & 4). |
| F5 | Quiz | Chord Progression: add note selection | In chord progression settings, add ability to choose: Root Note Only, Root + 3rd, Root + 5th, or Close Triad. Display should follow the Note Highlighting setting. Quiz should wait for all selected notes played in sequence before moving to the next chord. |
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
