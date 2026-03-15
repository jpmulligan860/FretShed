# What Did I Learn?

> A running journal of the most important lessons from building FretShed — not the technical nitty-gritty, but the process stuff. How to build better, work smarter with AI, and avoid stepping on the same rake twice.

---

## Executive Summary

Building FretShed from a working prototype to an App Store-ready product taught me a few things I won't forget:

**Device testing is king.** Every clever algorithm I built worked beautifully in unit tests and fell apart the moment a real guitar was involved. The low E string doesn't care about your math. Phase tracking, spectral gates, confidence thresholds — they all needed real-world validation. The single most productive thing I did on this project was plug in my Strat and play.

**Know your competition before you build.** I almost shipped with "the only app that listens to you play" as my tagline. Turns out five competitors already do that. The competitive analysis forced me to find what they *don't* do — calibration and adaptive learning — which became the features that actually matter. That one afternoon of research shaped months of architecture.

**AI is a force multiplier, not a replacement for judgment.** Claude.ai is spectacular at drafting plans, analyzing code, and catching patterns I'd miss. But it needs direction. The best sessions were the ones where I came in with a clear question or a specific problem. The worst were "just make it better." The split between Claude.ai (strategy, analysis, expert review) and Claude Code (implementation, testing, debugging) worked brilliantly once I stopped trying to use one tool for everything.

**Feature flags saved my sanity.** The `sustainMode` pattern — where tuner enhancements are gated behind a boolean that quiz mode never sets — meant I could experiment aggressively with the tuner without ever worrying about breaking the quiz. Every time I was tempted to "just change it globally," I reminded myself of the time a threshold tweak silently broke low-string detection in quizzes.

**Polish is not optional.** The gap between "it works" and "it ships" is enormous. Phase 3.6 was supposed to be 8 tasks. It became 14. Every one of those extra tasks made the app feel intentional instead of cobbled together. Budget 30% more time than you think you need for the last mile.

**Copy is a feature, not a garnish.** A systematic copy review — every string in every view, judged against a consistent tone — found ~30 changes in one pass. The difference between "Unable to start the microphone" and "Couldn't start the mic" is the difference between an app that feels like a developer made it and one that feels like a musician made it. Do the copy sweep before launch, not after.

**Audit before you monetize.** A structured 6-pass codebase review before Phase 4 found a silent sample rate bug, a backup data loss issue, and 28 other problems. Batching fixes by dependency order (schema → crashes → thread safety → logging → tests → cleanup) made each fix independently committable. The dead code deletion alone removed 600+ lines. Systematic reviews catch what incremental development misses — schedule one before every major milestone.

**If two systems advise the user, they must agree.** The insight engine and smart practice engine both analyzed mastery data independently — and gave contradictory advice. "Work on your D string" followed by a Full Fretboard quiz. The fix was simple: the message should come from the same engine that builds the session. Any time you have parallel recommendation systems, make one authoritative and the other a consumer.

**Layer your learning systems like your signal chain.** The Smart Practice Redesign stacked five independent systems (phase manager, temporal decay, note grouping, session planning, messaging) that each do one thing well. When they needed to communicate — like passing phase context from the Shed page through a quiz to the results screen — explicit data flow (coordinator properties) beat implicit coordination (both systems reading the same state independently) every time.

**Display functions must not mutate state.** A "peek" method that quietly advanced the learning phase before the pre-quiz snapshot was taken suppressed the celebration card entirely. The fix was obvious in hindsight: if a method's name suggests it reads state, it must not write state. Side effects in read paths create timing bugs that are invisible until a real user hits them — and they always do.

---

## Session Log

### Session: Feb 2026 — Phase 1 Cleanup
*The "Oh, There's More Technical Debt Than I Thought" Session*

1. **Always start by cleaning house.** I thought Phase 1 (cleanup) would be a quick 6-hour pass. It took closer to 9. Deleting the legacy `Presentation/` folder, auditing Settings, fixing Xcode warnings — each one surfaced something I didn't know was broken. Starting clean meant everything that followed was built on solid ground.

2. **A file manifest is worth its weight in gold.** Running `find . -name "*.swift" | sort > FILE_MANIFEST.txt` at the start of every session sounds pedantic, but it caught two near-duplicate files that would have caused merge hell later.

3. **Extract utilities early.** Pulling signal measurement functions (RMS, dBFS, noise floor) into `SignalMeasurement.swift` with 17 unit tests gave me a testable foundation that every future audio feature depended on. Best 1-hour investment of the project.

---

### Session: Feb 2026 — Design System & Woodshop
*The "Let's Make It Look Like a Guitar" Session*

1. **Design tokens first, visual redesign second.** Creating `DesignSystem.swift` with colors, typography, and spacing constants before touching any views meant the redesign was mechanical (find system color → replace with token) rather than creative (what color should this be?). Boring process, beautiful result.

2. **A visual redesign forces a comprehensive audit.** Replacing 458+ system colors across 18 files was tedious, but it caught dark mode bugs, inconsistent text hierarchies, and orphaned styling that I'd never have found otherwise. The sweep *was* the QA.

3. **Time your redesign right.** Doing Woodshop after core features were stable but before monetization meant I wasn't redesigning a half-built product (waste) or shipping a generic-looking app (missed opportunity).

---

### Session: Feb 2026 — Audio Calibration (F22)
*The "Wait, No Other App Does This?" Session*

1. **Competitive analysis should happen before architecture, not after.** I almost built a "listen and detect" app — which five competitors already offer. The afternoon I spent mapping the competitive landscape revealed that *calibration* was the real gap. That analysis shaped the entire F22 calibration system and became the core differentiator.

2. **Never claim "the only app that..."** unless you've verified it. I had the tagline ready. It was wrong. Embarrassment avoided by doing homework.

3. **Calibration is a trust-building moment.** When the app measures the user's room noise and guitar signal, it's saying "I'm adapting to *you*." That's a fundamentally different experience from "hope your room is quiet enough." The UX of the calibration flow matters as much as the DSP behind it.

---

### Session: Feb 2026 — Pitch Detection Hardening (F23–F25)
*The "One Gate Is Never Enough" Session*

1. **Layer your defenses.** Each detection gate (spectral flatness, consecutive frame, HPS octave, string-aware constraints, crest factor) catches a different failure mode. String slides fool the flatness gate but not the consecutive gate. Octave errors fool the consecutive gate but not HPS. You need all of them.

2. **Device testing reveals what unit tests can't.** The spectral flatness gate worked perfectly on synthetic signals. Then I played an acoustic guitar through the iPhone mic and the wound G string produced enough broadband energy to fail the gate every time. Real instruments are messy, beautiful, and completely uncooperative.

3. **Input source matters more than you'd think.** Built-in mic, USB interface, wired headset, and Bluetooth all have different frequency responses, noise floors, and latency characteristics. The `AudioInputSource` detection and per-source thresholds were not over-engineering — they were survival.

---

### Session: Feb 2026 — Expert Review
*The "Fresh Eyes Find Everything" Session*

1. **Schedule an expert review when the product is feature-complete but before monetization.** The 6-expert panel found 11 issues in one pass. Two were architectural showstoppers (NotificationCenter unreliability, quiz state management). Catching them before Phase 4 saved weeks of debugging.

2. **NotificationCenter is a trap.** It looks simple. It works in demos. Then you put a fullScreenCover over your TabView and the handlers silently stop firing. The pivot to direct closures + `QuizLaunchCoordinator` was painful but permanent. Document your architectural decisions so you don't repeat the experiment.

3. **Copy matters.** "Metronome in Quiz" → "Countdown Tick." "Single Note" → "Same Note." "Tap Mode" → "Tap Testing Mode." These seem trivial but they're the difference between an app that feels like a developer made it and an app that feels like a musician made it.

---

### Session: Mar 2026 — Shed Redesign (Phase 3.6)
*The "Fewer Taps to Playing" Session*

1. **Break big features into sub-phases.** Phase 3.6 was 14 tasks (SD.1–SD.14). Each was independently testable, independently committable, and independently estimable. When SD.9 (polish) took longer than expected, it didn't block SD.10–SD.14.

2. **Smart defaults beat configuration.** The baseline prior system (5 experience levels) seeds the Bayesian mastery model so the first quiz isn't random. Asking one question during onboarding saves 10 sessions of cold-start exploration. When your app has a learning algorithm, give it a head start.

3. **Polish is a phase, not an afterthought.** SD.9–SD.14 (the "polish" tasks) weren't bugs or features — they were refinements that made the Shed feel intentional. Auto-advance after mic permission. Branded launch screen. Repeat Last session tracking. Each one took 30-60 minutes and made a disproportionate difference.

---

### Session: Mar 2026 — Tuner Rewrite Phase 1–2 (T.P1, T.P2)
*The "Physics Models Beat Animation Hacks" Session*

1. **Replace animation hacks with physics models.** The original tuner used EMA smoothing + SwiftUI `.spring()` animation — two competing smoothing layers that fought each other. Replacing both with a single spring-damper physics model (TunerDisplayEngine) gave predictable, tunable behavior. One model, one source of truth.

2. **Halve the hop size, double the responsiveness.** Going from 1024-sample hops to 512-sample hops in sustain mode doubled the update rate to ~86 Hz. The tuner went from "laggy" to "instant" with no accuracy cost. Sometimes the simplest optimization is the best one.

3. **Feature flags protect your core product.** Every tuner enhancement was gated on `sustainMode`. Quiz detection remained byte-for-byte identical. When a threshold tweak broke low E detection in testing, I knew immediately it was a tuner-only issue because the quiz flag was false.

---

### Session: Mar 2026 — Tuner Drift Fix (T.P2.5)
*The "Phase Tracking Was a Beautiful Lie" Session*

1. **When clever math fails on real data, simplify.** Phase-based instantaneous frequency estimation is elegant, well-documented, and produces gorgeous results on synthetic sine waves. On a real guitar through a real mic? 0% phase frames, 98% fallback. I spent two sessions trying to make it work before accepting that magnitude-based parabolic interpolation was the right answer all along.

2. **Thread safety isn't optional in audio.** The crash during calibration profile creation was a classic data race — the audio thread writing to GoertzelTracker while the main thread called reset(). NSLock solved it. If your struct is accessed from two threads, it's not a value type anymore.

3. **First-frame transients are real.** The first Goertzel measurement after note lock consistently produced outlier readings (+619¢, -28¢) because peak magnitude hadn't stabilized. Adding an onset threshold (mag ratio ≥ 0.10) was a one-line fix that eliminated an entire class of visual glitches. Sometimes the best fix is "don't publish the first frame."

---

### Session: Mar 2026 — Diagnostic Tool & Device Testing
*The "Measure Everything" Session*

1. **Build diagnostic tools, not just features.** TunerDiagnosticView (#if DEBUG) captures per-frame Goertzel and YIN data across all 6 strings and generates a clipboard-ready report. Building it took 2 hours. It immediately revealed the G string octave error on built-in mic, the onset transient problem, and the input source detection bug. Those 2 hours saved at least 10 hours of guesswork.

2. **Test with multiple guitars and input methods.** USB interface gave ±1¢ accuracy. Built-in mic gave ±1.1¢ on 5/6 strings but the G string had an octave acquisition error. If I'd only tested one setup, I'd have shipped a bug. The diagnostic tool made multi-setup testing fast enough to actually do.

3. **Usability test your test tools.** The first version of the diagnostic auto-started recording the next string before I'd plucked it. Adding a `waitingForSilence` state fixed the usability — but I only discovered the issue by trying to use the tool myself. Even debug tools need UX.

---

### Session: Mar 2026 — Tuner Visual Polish (T.P3)
*The "Make the Needle Tell a Story" Session*

1. **State machines prevent UI flickering.** The TuningState hysteresis (noSignal → outOfRange → approaching → inTune → settled) with different entry/exit thresholds means the "IN TUNE" label doesn't flash on and off when the needle hovers near the threshold. Enter at ±2¢, exit at ±4¢. Simple, effective, obvious in hindsight.

2. **Color should communicate, not decorate.** Needle goes red → amber → green as you approach tune. Background washes green when settled. The level bar fades out once signal is established. Every visual change maps to a state transition. No gratuitous animation.

3. **Know when to stop.** T.P4 originally included intonation comparison mode and a ghost needle. After T.P3, I looked at those features and realized they were post-launch nice-to-haves, not launch requirements. Splitting them out to Phase 6 (tasks 6.6, 6.7) kept the tuner rewrite from expanding indefinitely.

---

### Session: Mar 2026 — Wrapping Up the Tuner
*The "Ship It and Move On" Session*

1. **Separate optimizations from features in your roadmap.** T.P4 mixed "adaptive update rate" (optimization, already done) with "intonation mode" (new feature) and "ghost needle" (new feature). Reviewing and splitting them saved me from feeling like there was still a whole phase of work when really it was already done.

2. **Document what you removed and why.** Phase tracking removal, onset threshold addition, thread safety fix — all documented in CLAUDE.md with rationale. Future me will want to try phase tracking again in 6 months. Past me left a note: "Don't. It doesn't work on real guitar signals."

3. **The two-AI workflow works.** Claude.ai for strategy, competitive analysis, expert review, and research. Claude Code for implementation, debugging, and testing. The Goertzel research findings doc (drafted in Claude.ai, implemented in Claude Code) was the cleanest handoff of the project. Define the interface between your AI tools the same way you'd define an API.

---

### Session: Mar 2026 — Copy Review & UI Polish (SD.16–SD.17)
*The "Words Matter More Than You Think" Session*

1. **Do a systematic copy review before launch.** Going through every user-facing string in one pass (organized by view, judged against a "knowledgeable guitar teacher" tone) found ~30 improvements. Individually small, collectively transformative. The app went from sounding like a developer wrote it to sounding like a musician wrote it.

2. **Tone consistency beats clever copy.** Having a single guiding principle — "knowledgeable guitar teacher: warm, encouraging, practical" — made every copy decision fast. "Unable to start the microphone" → "Couldn't start the mic." "Repetition is the key to mastery" → "Every rep gets you closer." No overthinking, just match the tone.

3. **Remove features from info sheets when you defer them.** Circle of Fourths/Fifths and Prioritize Weak Spots were deferred to post-launch but still appeared in the Focus Mode info sheet. Users don't care about your roadmap — if it's not in the app, it shouldn't be in the documentation.

4. **Duplicate UI affordances where users expect them.** Adding the filter menu next to the "RECENT SESSIONS" header (in addition to its original location) was a 5-minute change that makes the feature discoverable from the most obvious place. Don't make users hunt for controls.

5. **Context can run out at the worst time.** Two sessions in a row hit context limits during the session end protocol. The fix: keep sessions shorter, or front-load the creative work and leave the mechanical wrap-up for when context is thin. The session end checklist is long — start it earlier than you think.

---

### Session: Mar 2026 — Pre-Phase 4 Codebase Review
*The "Audit Before You Monetize" Session*

1. **Run a structured codebase audit before major milestones.** A 6-pass review (architecture, data layer, audio pipeline, view layer, App Store risks, code hygiene) found 28 issues — 7 critical. The I/O buffer sample rate bug (hardcoded 44100 when hardware runs at 48000) had been silently present since the tuner rewrite. Systematic audits catch what incremental development misses.

2. **Batch your fixes by dependency order.** Schema changes first (they affect backup compatibility), then crash fixes, then thread safety, then logging, then tests, then cleanup. Each batch was independently committable and testable. No batch blocked another.

3. **Dead code removal is underrated.** Deleting DecayStabilizer (-17 tests, -200 lines) and NotificationScheduler (-400 lines) reduced the codebase surface area measurably. Both files were "keeping for later" candidates that had been superseded months ago. If it's in git history, it doesn't need to be in the repo.

4. **Write tests for your data pipeline, not just your algorithms.** The 14 BackupManager round-trip tests caught the missing sessionTimeLimitSeconds field immediately. Before these tests, a user could export, import, and silently lose all their timed session data. The bug had existed since the field was added.

---

### Session: Mar 2026 — Session Insight Engine
*The "Your Two Systems Need to Talk to Each Other" Session*

1. **If two systems advise the user, they must agree.** SessionInsightEngine and SmartPracticeEngine both analyzed mastery data independently. The insight card said "work on your D string" and then Smart Practice launched a Full Fretboard quiz. The fix was obvious once spotted: the Shed CTA message should come from the same engine that builds the session. Independent analysis → coherent recommendation.

2. **Check if your view is actually used before wiring into it.** SessionSummaryView existed as a complete, well-built view — and nothing in the app ever instantiated it. The real session results live in QuizView's `completedContent`. I wired the insight card into the wrong view and only found out during device testing. `grep` for instantiation sites before you start editing.

3. **Temporal modifiers sound good on paper, terrible in practice.** "Welcome back. Your D string needs work." reads like two unrelated sentences glued together. Context-aware prefixes add cognitive load without adding value. The insight headline should stand on its own — if it needs a preamble, the headline isn't good enough.

4. **Non-scrollable layouts and dynamic content don't mix.** The session results used a fixed VStack with Spacers. Adding the insight card meant it got squeezed into whatever space was left. Switching to ScrollView with pinned buttons was the right call — always assume content will grow.

5. **Side effects in "peek" methods will ruin your day.** SmartPracticeEngine.nextSession() rotated the mode on every call. Using it to generate a description for the CTA would have rotated the mode every time the Shed page appeared. A separate `peekNextSessionDescription()` with no side effects was essential.

---

### Session: Mar 2026 — Smart Practice Redesign (SP.1–SP.6)
*The "Stack Five Systems and Make Them Talk" Session*

1. **Explicit data flow beats implicit coordination.** Passing phase context from Shed → quiz → results required three stops: snapshot the phase before quiz (`coordinator.phaseBeforeQuiz`), carry the session groups (`coordinator.lastSessionGroups`), then compare post-quiz phase to detect advancement. Every attempt to have both ends read the same state independently produced subtle bugs. The coordinator-as-bridge pattern worked because it made the data flow visible and debuggable.

2. **Templated messages need automated vocabulary enforcement.** PhaseInsightLibrary has ~70 templates with banned words ("dropped", "regressed", "back to", "lost"). A unit test that checks every template against the banned list caught "back to" in a review session message on the first run. Automated enforcement is non-negotiable when your message pool is large enough that manual review will miss things.

3. **Phase-specific heatmap overlays are cheap and informative.** Computing `focusCells` from LearningPhaseManager state and overlaying a cherry border on matching cells was ~40 lines of code. The visual payoff is disproportionate — users immediately see where the app wants them to focus. The key insight: different phases need different overlay strategies (single string vs. cross-string vs. full region vs. none).

4. **Context windows have a budget — front-load creative work.** Two sessions in a row hit context limits during the session end protocol. The Smart Practice Redesign was 6 phases of implementation-heavy work. The lesson: do the implementation and testing first, then the mechanical wrap-up (CLAUDE.md, ROADMAP.md, commit). Don't save creative decisions for when context is thin.

5. **Access control matters even in single-module apps.** QuizView was marked `public` for no reason. Adding `phaseBeforeQuiz: LearningPhase?` to its init immediately failed because LearningPhase is internal. The fix was trivial (remove `public`), but it's a reminder: default to internal, only widen access when you have a reason.

---

### Session: Mar 2026 — Phase Transition Bug Fixes (SP.7)
*The "Users Don't Follow Your Happy Path" Session*

1. **Test with real data, not just fresh installs.** The Foundation phase got stuck because `currentTargetString` was nil — something that only happens when TestDataSeeder creates mastery data without calling `initializeForBaseline()`. Auto-recovery code (`autoDetectCompletedStrings()`) was needed because real users accumulate state in ways your init flow doesn't anticipate.

2. **Evaluation functions should not live in display functions.** `phaseDisplayInfo()` called `evaluateAdvancement()` as a side effect, which could advance the phase *before* the pre-quiz snapshot was taken — suppressing the celebration card. Making display functions purely read-only eliminated an entire class of race conditions. If a method's name suggests it reads state, it shouldn't write state.

3. **Gate fast progression explicitly.** Users with prior mastery could skip Foundation → Connection → Expansion in a single session because advancement criteria were already satisfied from earlier play. A simple `sessionsInCurrentPhase` minimum (3 sessions) prevents phase-skipping while still allowing natural progression. Not every constraint is pedagogically deep — sometimes "slow down" is the right answer.

4. **When two UI elements recommend actions, they must agree.** The "Next Up" button showed one session description but launched a different session because `insightCard.targetNotes` was always passed regardless of which recommendation was displayed. Adding a tracking flag (`nextSessionUsesTargetNotes`) that matches the label to the action was a 3-line fix for a deeply confusing UX bug.

5. **Contradictions destroy trust.** A trophy card saying "Steady but flat" appearing above a "PHASE COMPLETE!" celebration makes the user doubt both messages. When two independent systems (insight engine + phase advancement) generate results screen content, the more significant event must override the less significant one. Phase advancement > session insight, always.
