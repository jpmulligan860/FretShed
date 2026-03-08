# FretShed — App Store Roadmap

> **Goal**: App Store submission and first paying users.
> **Estimate**: 58–80 hours total · 12–20 weeks at 4–5 hrs/week · 7–10 weeks at 8 hrs/week
> **Status key**: ✅ Done · 🔲 Not started · 🚧 In progress

---

## Current State (Baseline)

The core product is feature-complete and well-architected:

- 5 fully implemented tabs (Practice, Progress, Tuner, MetroDrone, Settings)
- 7 quiz focus modes + 4 game modes + adaptive weighting
- Bayesian mastery algorithm with 6×12 heatmap
- Live pitch detection (AccelerateYIN)
- Metronome + drone generator (AVAudioEngine)
- SwiftData persistence + repository pattern
- 219 unit tests (3 pre-existing failures unrelated to feature work)
- Full audio calibration system (F22) — required before quiz, pre-seeds PitchDetector
- Advanced pitch detection: spectral flatness gate, consecutive frame gate, HPS octave verification, string-aware frequency constraints, 50 Hz HPF, input-source-aware low-frequency emphasis, adaptive spectral subtraction, distortion tolerance (crest factor, harmonic regularity, input-aware flatness threshold), tuner sustain hysteresis (F29)
- Piano drone timbre (F26), practice streak tracker (F27), tap mode bypass for calibration (F28)
- Swift 6 strict concurrency

> **Product name decided**: FretShed: Guitar Fretboard · Bundle ID: `com.jpm.fretshed` (locked in App Store Connect)

---

## Phase 1 — Cleanup & Architecture

**Remove technical debt before adding anything new.**
Estimated: 6–9 hours

| # | Task | Est. | Status |
|---|---|---|---|
| 1.1 | Generate full file manifest — `find . -name "*.swift" \| sort > FILE_MANIFEST.txt` | 30 min | ✅ |
| 1.2 | Delete `Presentation/` legacy folder — confirm nothing references it, then delete and clean build | 1–2 hrs | ✅ |
| 1.3 | Audit Settings tab — trim to essentials (Display, Audio, Quiz Defaults, Data Management only) | 1–2 hrs | ✅ |
| 1.4 | Fix all Xcode warnings — run a clean build and resolve every yellow warning | 1–2 hrs | ✅ |
| 1.5 | Run full test suite — confirm all 189 tests pass | 30 min | ✅ |
| 1.6 | Test every tab on a physical iPhone | 1 hr | ✅ |
| 1.7 | Create `BUGLOG.md` in the project root — track all discovered issues | 30 min | ✅ |
| 1.8 | Extract signal measurement utilities (`SignalMeasurement.swift`) — RMS, dBFS, noise floor, gate threshold; 17 unit tests | 1 hr | ✅ |

---

## Phase 2 — Design System

**Establish a consistent visual language across the whole app.**
Estimated: 18–25 hours

### 2A — Design Tokens (Do This First)

| # | Task | Est. | Status |
|---|---|---|---|
| 2.1 | Create `DesignSystem.swift` — centralized colors, typography, spacing constants | 1 hr | ✅ |
| 2.2 | Define color palette — primary accent, background, surface, text, success, error | 30 min | ✅ |
| 2.3 | Define typography scale — Title, Headline, Body, Caption as `Font` extensions | 30 min | ✅ |
| 2.4 | Define spacing constants — xs(4pt), sm(8pt), md(16pt), lg(24pt), xl(32pt) | 30 min | ✅ |

### 2B — Apply Design System to Each Tab

| # | Task | Est. | Status |
|---|---|---|---|
| 2.5 | Redesign Practice tab — hero card, quick-start grid, `SessionSetupView` | 2–3 hrs | ✅ |
| 2.6 | Redesign Quiz / `FretboardView` — clean fretboard, clear feedback states | 2–3 hrs | ✅ |
| 2.7 | Redesign Progress tab — heatmap color coding, mastery ring, scannable session list | 2 hrs | ✅ |
| 2.8 | Redesign Tuner tab — clean needle/strobe display | 1–2 hrs | ✅ |
| 2.9 | Redesign MetroDrone tab — prominent BPM, clearly grouped controls | 1–2 hrs | ✅ |
| 2.10 | Redesign Settings tab — clean and grouped, iOS native list style | 1 hr | ✅ |

### 2C — Empty States

| # | Task | Est. | Status |
|---|---|---|---|
| 2.11 | Progress tab empty state — "Complete your first session…" with Start Practicing button | 1 hr | ✅ |
| 2.12 | Session history empty state | 30 min | ✅ |
| 2.13 | Quiz completion screen polish — feels like achievement, shows score/streak/mastery change | 1–2 hrs | ✅ |

### 2D — Loading & Error States

| # | Task | Est. | Status |
|---|---|---|---|
| 2.14 | Add loading states to Progress tab — skeleton or spinner | 1 hr | ✅ |
| 2.15 | Mic permission denied state — clear explanation + "Go to Settings" button | 1 hr | ✅ |
| 2.16 | Audio detection failure state — gentle message + offer tap mode fallback | 1 hr | ✅ |
| 2.17 | Generic error handling — user-friendly messages, no blank screens or crashes | 1 hr | ✅ |

---

## Phase 3 — Onboarding

**The first experience defines whether users stay.**
Estimated: 6–8 hours

| # | Task | Est. | Status |
|---|---|---|---|
| 3.1 | `OnboardingView` screen 1: Welcome — value prop, app icon, "Get Started" button | 1 hr | ✅ |
| 3.2 | `OnboardingView` screen 2: How it works — 3 bullet points max | 1 hr | ✅ |
| 3.3 | `OnboardingView` screen 3: Mic permission — explain WHY before triggering system prompt | 1–2 hrs | ✅ |
| 3.4 | `OnboardingView` screen 4: Audio test — play any open string, app shows detected note | 1–2 hrs | ✅ |
| 3.5 | Wire onboarding to app launch — show only on first launch via `UserDefaults` (`hasCompletedOnboarding`) | 30 min | ✅ |
| 3.6 | Add "Skip" option — allow skipping from screen 2 onward | 30 min | ✅ |
| 3.7 | Test on device — cold launch → onboarding → Practice tab → 'Use Tap Mode' → Session Setup → Start → first quiz question (target: under 60s). Also test audio path: Do This First → Use Audio Detection → tune → Calibrate → success → Session Setup → Start (target: under 3 min including tuning). | 30 min | ✅ |

---

## Phase 3.5 — Visual Redesign ("Woodshop")

**Cherry sunburst Les Paul aesthetic — premium look before monetization.**

| # | Task | Est. | Status |
|---|---|---|---|
| A1 | Color palette — full Woodshop adaptive light/dark palette in DesignSystem.swift | M | ✅ |
| A2 | Typography scale — Montserrat + Crimson Pro + JetBrains Mono three-family system | M | ✅ |
| A3 | Font files — download 10 TTFs, register in Info.plist, add to Xcode project | M | ✅ |
| A4 | Gradients + view modifiers — sunburst gradients, `.woodshopCard()`, `.primaryButtonStyle()` | S | ✅ |
| B1 | Tab bar — rename tabs (Shed, Journey, Tuner, Tempo, Setup), cherry tint | M | ✅ |
| B2 | App shell — warm launch screen, sunburst gradient "FretShed" text | S | ✅ |
| C1 | Settings — "Setup" nav title, CAPS section headers, warm colors throughout | M | ✅ |
| D1 | Tuner — warm background, Montserrat note display, amber needle, Woodshop tuning colors | M | ✅ |
| E1 | Practice Home — "The Shed" title + Crimson Pro subtitle, gradient cards, cherry icons | L | ✅ |
| F1 | Session Setup — cherry chips, gradient start button, correct-tinted toggles | L | ✅ |
| G1 | Quiz View — cherry/amber stats, warm surfaces, Woodshop feedback colors | L | ✅ |
| G2 | Fretboard — rosewood background, cream nut, amber target dot | M | ✅ |
| G3 | Session Summary — warm surfaces, Woodshop mastery colors, gradient buttons | S | ✅ |
| H1 | Progress Tab — "Journey" nav title, cherry/amber charts, CAPS headers | L | ✅ |
| H2 | Mastery Heatmap — sunburst progression (cherry→amber→gold→correct) | M | ✅ |
| H3 | Cell Detail Sheet — surface2 backgrounds, smallLabel typography | S | ✅ |
| H4 | Session Detail + Heatmap — cherry/amber mode colors, warm surfaces | S | ✅ |
| I1 | MetroDrone — cherry metronome, amber drone, warm card backgrounds | L | ✅ |
| J1 | Calibration View — cherry icons, gradient buttons, correct checkmarks | M | ✅ |
| J2 | Calibration Tuner — matching Phase D tuner styling | S | ✅ |
| K1 | Onboarding — cherry/amber/gold feature icons, gradient buttons, warm background | M | ✅ |
| L1 | Remove deprecated aliases — zero stray Color.indigo/teal/systemGroupedBackground | M | ✅ |
| L2 | Light/dark mode audit — pending device testing | M | ✅ |
| L3 | Full test suite — 219 tests, 3 pre-existing failures (unrelated to redesign) | S | ✅ |

---

## Phase 3.6 — Shed Redesign

**Fewer taps to playing, smarter defaults, new onboarding baseline screen.**

| # | Task | Status |
|---|---|---|
| SD.1 | Baseline Prior System + New Focus Modes — `BaselineLevel` enum (5 cases), `naturalNotes`/`sharpsAndFlats` FocusModes, `isFreeMode`, baseline prior weighting in QuizViewModel | ✅ |
| SD.2 | Onboarding Baseline Screen — "Where are you at?" screen (4th onboarding page), saves BaselineLevel to UserDefaults | ✅ |
| SD.3 | Smart Practice Engine — `SmartPracticeEngine` class, focus mode rotation (Full Fretboard → Single String → Same Note), targets weakest areas | ✅ |
| SD.4 | Timed Practice Support — `sessionTimeLimitSeconds` on Session, countdown timer in QuizViewModel, auto-complete on expiry | ✅ |
| SD.5 | Compact Heatmap Component — `CompactHeatmapView` (6×13 grid, 3-label legend) for Shed page | ✅ |
| SD.6 | Half-Sheet Session Builder — `.sheet` with `.presentationDetents`, chip-based UI, premium lock icons | ✅ |
| SD.7 | Shed Page Layout Rewrite — Smart Practice CTA, calibration banner, compact heatmap, quick start presets, timed practice, build custom button | ✅ |
| SD.8 | Wire Up & Integration Testing — All launch paths verified, 230 tests passing (3 pre-existing failures), no migration errors | ✅ |
| SD.9 | Shed Page Polish — CTA label fix, remove compact heatmap, rework quick start tiles (`alternativeSessions()`), "Got Time?" timed picker | ✅ |
| SD.10 | Onboarding Polish — Auto-advance after mic permission, baseline page top padding fix | ✅ |
| SD.11 | Quiz Polish — sharpsAndFlats note format override (force `.both`), timed session countdown timer pill | ✅ |
| SD.12 | Branded Launch Screen — LaunchScreen.storyboard with Woodshop colors, replaces blank UILaunchScreen | ✅ |
| SD.13 | Repeat Last Session Tracking — coordinator-based `lastCompletedSession`, `isNewUser` fix, `sessionTimeLimitSeconds` copy on repeat | ✅ |
| SD.14 | Repeat Last Subtitle + "Same Note" Rename — full focus mode + game mode subtitle, 2-line limit, FocusMode.singleNote label → "Same Note" | ✅ |

---

## Tuner Rewrite

**4-phase professional tuner upgrade: quick wins → core architecture → visual presentation → differentiators.**

| # | Task | Status |
|---|---|---|
| T.P1 | Phase 1 Quick Wins — I/O buffer reduction, sub-cent display, sharp/flat labels, 2-frame gate, HPF/maxTau for Drop C/D, BT latency warning | ✅ |
| T.P2 | Phase 2 Core Architecture — Lightweight tap fast path, tracking mode, cents-space filtering, adaptive YIN threshold, TunerDisplayEngine (spring-damper), rewire TunerView | ✅ |
| T.P2.5 | Phase 2.5 Pitch Drift Fix — Goertzel hybrid tracker (magnitude-based 3-bin parabolic interpolation, onset suppression, decay detection), thread-safe NSLock integration, TunerDiagnosticView, input source auto-detection, 17 unit tests | ✅ |
| T.P3 | Phase 3 Visual Presentation — Settled readout, in-tune hysteresis state machine (5 states with hysteresis thresholds), background color wash, string indicator pill, responsive dial (tick labels, state-aware needle/pivot color, green zone glow), auto-hide level bar | ✅ |
| T.P4 | Phase 4 Adaptive Update Rate — Hop size halved in sustain mode, spring-damper gain scheduling, hysteresis state machine adapts display behavior | ✅ (absorbed into T.P2/T.P2.5/T.P3) |

---

## Phase 4 — Monetization

**StoreKit 2 paywall — your revenue engine.**
Estimated: 10–13 hours

> **Bundle ID locked**: `com.jpm.fretshed` (App Store Connect)
> **Subtitle**: "Learn Every Fretboard Note"

### Finalized Business Decisions

| Decision | Value |
|---|---|
| **Free tier modes** | Full Fretboard + Single String only |
| **Free tier fretboard** | Strings 4–6, frets 0–7 |
| **Free tier features** | Audio detection ON, adaptive ON, full stats, built-in mic calibration |
| **Premium modes** | All 7 focus modes (adds Single Note, Fretboard Position, Circle of 4ths/5ths, Chord Progression) |
| **Premium fretboard** | All 6 strings, all frets |
| **Premium extras** | USB/BT calibration profiles, unlimited history |
| **Pricing** | $4.99/mo · $29.99/yr · $49.99 lifetime |
| **Trial** | 14-day free trial on monthly and annual |
| **Analytics** | TelemetryDeck (privacy-focused, no PII) |

### 4A — Business Setup (No Coding Required)

| # | Task | Est. | Status |
|---|---|---|---|
| 4.1 | Create Apple Developer account — developer.apple.com, $99/year, allow 24–48 hrs for approval | 30 min + wait | ✅ |
| 4.2 | Create app in App Store Connect — choose and lock in Bundle ID | 30 min | 🔲 |
| 4.3 | Create subscription products — monthly ($4.99/mo), annual ($29.99/yr), lifetime ($49.99), with 14-day free trials on monthly/annual | 1 hr | 🔲 |
| 4.4 | Set up sandbox test account — App Store Connect > Users and Access > Sandbox Testers | 30 min | 🔲 |

### 4B — EntitlementManager

| # | Task | Est. | Status |
|---|---|---|---|
| 4.5 | Build `EntitlementManager.swift` — `@Observable` class, check StoreKit 2 subscription status, expose `isPremium: Bool` | 2–3 hrs | 🔲 |
| 4.6 | Inject `EntitlementManager` into `AppContainer` via `@Environment` | 30 min | 🔲 |
| 4.7 | Define free vs premium gates — Free: Full Fretboard + Single String modes, strings 4–6, frets 0–7, audio detection, adaptive, full stats. Premium: all 7 focus modes, all strings/frets, USB/BT calibration profiles, unlimited history. | 1 hr | 🔲 |

### 4C — PaywallView

| # | Task | Est. | Status |
|---|---|---|---|
| 4.8 | Build `PaywallView.swift` — 3 value prop bullets, monthly/annual/lifetime toggle, 14-day trial callout, Subscribe + Restore buttons, legal text | 2–3 hrs | 🔲 |
| 4.9 | Add required legal text — trial length, price after trial, auto-renewal terms, cancellation instructions (required to avoid App Store rejection) | 30 min | 🔲 |
| 4.10 | Add paywall triggers — show when user taps a locked mode or a locked fret/string range | 1 hr | 🔲 |
| 4.11 | Test purchases with sandbox account — complete test purchase, confirm `isPremium` flips, test restore | 1 hr | 🔲 |

### 4D — Analytics

| # | Task | Est. | Status |
|---|---|---|---|
| 4.12 | Add TelemetryDeck SDK via SPM — privacy-focused analytics, no PII collection | 30 min | 🔲 |
| 4.13 | Define key events — session_started, session_completed, paywall_shown, subscription_started, calibration_completed, onboarding_completed, quiz_first_completed | 30 min | 🔲 |

---

## Phase 5 — App Store Submission

**The final sprint to launch.**
Estimated: 18–25 hours

### 5A — Required Assets

| # | Task | Est. | Status |
|---|---|---|---|
| 5.1 | App icon — 1024×1024 PNG, use Xcode asset catalog to generate all sizes | 2–4 hrs | 🔲 |
| 5.2 | App Store screenshots — iPhone 6.9" (iPhone 16 Pro Max), at least 3, up to 10 | 2–3 hrs | 🔲 |
| 5.3 | Add benefit text overlays to screenshots — use Canva for 1-line callout text per screen | 1–2 hrs | 🔲 |
| 5.4 | App Preview video (optional) — 15–30 seconds, QuickTime via iPhone cable | 1–2 hrs | 🔲 |

### 5B — Legal & Privacy

| # | Task | Est. | Status |
|---|---|---|---|
| 5.5 | Privacy Policy — termly.io (free); specify mic use, local storage only, no third-party sharing | 1 hr | 🔲 |
| 5.6 | Host Privacy Policy on WordPress — publish at `fretshed.com/privacy` (site is live on SiteGround GrowBig, Woodshop theme) | 30 min | 🔲 |
| 5.7 | Support URL — `fretshed.com/support` with WPForms contact form (required by Apple) | 30 min | 🔲 |
| 5.8 | Add `PrivacyInfo.xcprivacy` to project — declare microphone usage and `NSUserDefaults` access (missing = auto-rejection) | 1 hr | 🔲 |
| 5.9 | Complete App Store privacy nutrition label — data not collected (on-device only) | 30 min | 🔲 |

### 5C — App Store Metadata

| # | Task | Est. | Status |
|---|---|---|---|
| 5.10 | App Name (30 chars) and Subtitle (30 chars) | 15 min | 🔲 |
| 5.11 | Keywords (100 chars): guitar, fretboard, notes, learn, trainer, ear, strings, frets, practice, quiz, memorize, tuner, mastery | 15 min | 🔲 |
| 5.12 | App Description — lead with calibration + adaptive learning hook (NOT "only app that listens" — competitors have audio detection too). Use revised positioning from `FretShed_Competitive_Analysis.md`: Problem (detection unreliability) → Solution (calibration + adaptive mastery) → Features → Social proof | 1–2 hrs | 🔲 |
| 5.13 | Age rating questionnaire — should be 4+ | 15 min | 🔲 |
| 5.14 | App Review Notes — explain mic usage to reviewers, mention tap mode fallback | 15 min | 🔲 |

### 5D — TestFlight Beta

| # | Task | Est. | Status |
|---|---|---|---|
| 5.15 | Archive and upload build — Xcode: Product > Archive > Distribute App > App Store Connect | 1 hr | 🔲 |
| 5.16 | Set up TestFlight beta group — up to 100 testers, write "What to Test" note | 30 min | 🔲 |
| 5.17 | Recruit 20–30 beta testers — offer 3-month free premium at launch as incentive | 1 hr | 🔲 |
| 5.18 | Run beta for 2–3 weeks — collect feedback, fix top 3 issues, re-upload build | 5–8 hrs | 🔲 |

### 5D.5 — Accuracy Testing Protocol

| # | Task | Est. | Status |
|---|---|---|---|
| 5.18a | Develop accuracy testing protocol — documented procedure: tune each guitar with a reference tuner (PolyTune or similar), run TunerDiagnosticView on all 6 strings, record final held readings. Test across 3–5 guitars (electric + acoustic), both input methods (USB interface + built-in mic), open strings + 5th/9th/12th fret. Document results to back a defensible accuracy claim (e.g., "Sub-5 cent accuracy on all strings") for App Store description (Task 5.12). | 2–3 hrs | 🔲 |

### 5D.6 — Device Compatibility Testing

| # | Task | Est. | Status |
|---|---|---|---|
| 5.18b | Device compatibility audit — test all 5 tabs + quiz + calibration on multiple screen sizes using Xcode Simulator: iPhone SE (3rd gen, 4.7"), iPhone 16 (6.1"), iPhone 16 Pro Max (6.9"), iPad (if supporting). Check: layout doesn't clip or overflow, text is readable, fretboard heatmap scales properly, tuner dial fits, landscape mode works on all sizes. Fix any layout issues. | 2–3 hrs | 🔲 |
| 5.18c | Dynamic Type testing — test with accessibility text sizes (Large, Extra Large, AX1) in Simulator. Verify key screens (tuner, quiz, session setup, progress) remain usable. Fix critical clipping/overflow issues. | 1–2 hrs | 🔲 |

### 5E — Final Pre-Submission Checklist

| # | Task | Est. | Status |
|---|---|---|---|
| 5.19 | Run full test suite one final time — all 214 tests must pass | 30 min | 🔲 |
| 5.20 | Test every tab on a physical device — fresh install, go through onboarding, no crashes | 1–2 hrs | 🔲 |
| 5.21 | Test StoreKit in sandbox — full purchase flow: monthly, annual, cancel, restore | 1 hr | 🔲 |
| 5.22 | Confirm mic permission flow — deny then grant, both paths handled gracefully | 30 min | 🔲 |
| 5.23 | Submit for App Store Review — set pricing, select build, fill metadata, click Submit | 1 hr | 🔲 |

---

## Phase 6 — Post-Launch

| # | Task | Est. | Status |
|---|---|---|---|
| 6.1 | Pre-launch email sequence — 4-week drip (teaser, feature deep-dive, early access, launch day). Detailed implementation plan in ROADMAP_STRATEGY Phase S6B (MailerLite) | 2–3 hrs | 🔲 |
| 6.2 | Reddit/YouTube community outreach — r/guitarlessons, r/learnguitar, relevant YouTube channels. Detailed implementation plan in ROADMAP_STRATEGY Phase S6D (Reddit) | 2–3 hrs | 🔲 |
| 6.3 | "Suggested Next Session" on quiz results screen — recommend next focus based on weak spots | 2–3 hrs | 🔲 |
| 6.4 | Full accessibility audit — VoiceOver, Dynamic Type, color contrast across all screens | 4–6 hrs | 🔲 |
| 6.5 | Auto-tune PitchDetector from accuracy assessment data — analyze per-attempt detection metadata (confidence, cents, frequency) to auto-adjust per-string confidence thresholds, consecutive frame gate, and spectral flatness threshold. Prerequisite: detection metadata capture (shipped). | 3–4 hrs | 🔲 |
| 6.6 | Tuner: Intonation comparison mode — play open string then 12th fret, compare readings to verify guitar intonation setup | 3–4 hrs | 🔲 |
| 6.7 | Tuner: Pitch rate predictor (ghost needle) — translucent needle showing where pitch is heading based on rate of change | 2–3 hrs | 🔲 |

---

## Time Summary

| Phase | Description | Est. Hours |
|---|---|---|
| Phase 1 | Cleanup & Architecture | 6–9 hrs |
| Phase 2 | Design System | 18–25 hrs |
| Phase 3 | Onboarding | 6–8 hrs |
| Phase 4 | Monetization | 10–13 hrs |
| Phase 5 | App Store Submission | 18–25 hrs |
| Phase 6 | Post-Launch | 10–15 hrs |
| **Total** | | **68–95 hrs** |

---

## How to Use This Roadmap

Work through phases in order — each phase builds on the last. Do not jump to Phase 4 (Monetization) until Phases 1–3 are solid.

For each task, open Claude Code and say:

> "Help me complete task [number]: [task name]"

Then share the relevant Swift files. Every task on this list is Claude-assisted — you do not need to write code from scratch.

Mark tasks complete by changing `🔲` to `✅` as you go. When a full phase is done, that's a real milestone worth acknowledging.

**You already built the hard parts. Everything here is execution, not invention.**

---

## Sync Ledger

> See `SYNC_PROTOCOL.md` for how this works. Claude Code owns this file; Claude.ai reads only.

### Outbound (changes Claude.ai needs to know about)
| Date | What Changed | Target | Status |
|---|---|---|---|
| | | | |

### Inbound (changes requested by Claude.ai)
| Date | Change Requested | Source | Status |
|---|---|---|---|
| 2026-03-03 | Task 5.6: Change Carrd → WordPress. "Host Privacy Policy on WordPress — publish at `fretshed.com/privacy`" | ROADMAP_STRATEGY.md | ✅ Applied |
| 2026-03-03 | Task 5.7: Change Carrd → WordPress. "Support URL — `fretshed.com/support` with WPForms contact form" | ROADMAP_STRATEGY.md | ✅ Applied |
| 2026-03-03 | Task 4.13: Add events `onboarding_completed` and `quiz_first_completed` to key events list | ROADMAP_STRATEGY.md | ✅ Applied |
| 2026-03-03 | Phase 6: Tasks 6.1 and 6.2 — add cross-references to ROADMAP_STRATEGY Phase S6B and S6D | ROADMAP_STRATEGY.md | ✅ Applied |
