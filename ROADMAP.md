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
- 219 passing unit tests
- Full audio calibration system (F22) — required before quiz, pre-seeds PitchDetector
- Advanced pitch detection: spectral flatness gate, consecutive frame gate, HPS octave verification, string-aware frequency constraints, 60 Hz HPF, input-source-aware low-frequency emphasis, adaptive spectral subtraction, distortion tolerance (crest factor, harmonic regularity, input-aware flatness threshold)
- Swift 6 strict concurrency

> **Note on naming**: The Xcode project is `FretShed`; the MVP plan targets the `FretShed` brand. Decide on a final product name before Phase 4 (bundle IDs are permanent once submitted).

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
| 3.7 | Test on device — cold launch → onboarding → Practice tab → 'Use Tap Mode' → Session Setup → Start → first quiz question (target: under 60s). Also test audio path: Do This First → Use Audio Detection → tune → Calibrate → success → Session Setup → Start (target: under 3 min including tuning). | 30 min | 🔲 |

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
| L2 | Light/dark mode audit — pending device testing | M | 🔲 |
| L3 | Full test suite — 219 tests, 3 pre-existing failures (unrelated to redesign) | S | ✅ |

---

## Phase 4 — Monetization

**StoreKit 2 paywall — your revenue engine.**
Estimated: 10–13 hours

> **Decide your product name before this phase.** The bundle ID (`com.yourname.fretshed`) is permanent once set in App Store Connect.

### 4A — Business Setup (No Coding Required)

| # | Task | Est. | Status |
|---|---|---|---|
| 4.1 | Create Apple Developer account — developer.apple.com, $99/year, allow 24–48 hrs for approval | 30 min + wait | 🔲 |
| 4.2 | Create app in App Store Connect — choose and lock in Bundle ID | 30 min | 🔲 |
| 4.3 | Create subscription products — monthly ($4.99/mo) and annual ($29.99/yr), both with 7-day free trials | 1 hr | 🔲 |
| 4.4 | Set up sandbox test account — App Store Connect > Users and Access > Sandbox Testers | 30 min | 🔲 |

### 4B — EntitlementManager

| # | Task | Est. | Status |
|---|---|---|---|
| 4.5 | Build `EntitlementManager.swift` — `@Observable` class, check StoreKit 2 subscription status, expose `isPremium: Bool` | 2–3 hrs | 🔲 |
| 4.6 | Inject `EntitlementManager` into `AppContainer` via `@Environment` | 30 min | 🔲 |
| 4.7 | Define free vs premium gates — Free: Single Note mode, strings 4–6, frets 0–7, tap input, 7-day history. Premium: everything else. | 1 hr | 🔲 |

### 4C — PaywallView

| # | Task | Est. | Status |
|---|---|---|---|
| 4.8 | Build `PaywallView.swift` — 3 value prop bullets, monthly vs annual toggle, 7-day trial callout, Subscribe + Restore buttons, legal text | 2–3 hrs | 🔲 |
| 4.9 | Add required legal text — trial length, price after trial, cancellation instructions (required to avoid App Store rejection) | 30 min | 🔲 |
| 4.10 | Add paywall triggers — show when user taps a locked mode, after 5th free session, or tries audio mode on free tier | 1 hr | 🔲 |
| 4.11 | Test purchases with sandbox account — complete test purchase, confirm `isPremium` flips, test restore | 1 hr | 🔲 |

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
| 5.6 | Host Privacy Policy — e.g. Carrd.co (free), at `fretshed.carrd.co/privacy` | 30 min | 🔲 |
| 5.7 | Support URL — `fretshed.carrd.co/support` (required by Apple) | 30 min | 🔲 |
| 5.8 | Add `PrivacyInfo.xcprivacy` to project — declare microphone usage and `NSUserDefaults` access (missing = auto-rejection) | 1 hr | 🔲 |
| 5.9 | Complete App Store privacy nutrition label — data not collected (on-device only) | 30 min | 🔲 |

### 5C — App Store Metadata

| # | Task | Est. | Status |
|---|---|---|---|
| 5.10 | App Name (30 chars) and Subtitle (30 chars) | 15 min | 🔲 |
| 5.11 | Keywords (100 chars): guitar, fretboard, notes, learn, trainer, ear, strings, frets, practice, quiz, memorize, tuner, mastery | 15 min | 🔲 |
| 5.12 | App Description — lead with audio detection hook: Problem → Solution → Features → Social proof | 1–2 hrs | 🔲 |
| 5.13 | Age rating questionnaire — should be 4+ | 15 min | 🔲 |
| 5.14 | App Review Notes — explain mic usage to reviewers, mention tap mode fallback | 15 min | 🔲 |

### 5D — TestFlight Beta

| # | Task | Est. | Status |
|---|---|---|---|
| 5.15 | Archive and upload build — Xcode: Product > Archive > Distribute App > App Store Connect | 1 hr | 🔲 |
| 5.16 | Set up TestFlight beta group — up to 100 testers, write "What to Test" note | 30 min | 🔲 |
| 5.17 | Recruit 20–30 beta testers — offer 3-month free premium at launch as incentive | 1 hr | 🔲 |
| 5.18 | Run beta for 2–3 weeks — collect feedback, fix top 3 issues, re-upload build | 5–8 hrs | 🔲 |

### 5E — Final Pre-Submission Checklist

| # | Task | Est. | Status |
|---|---|---|---|
| 5.19 | Run full test suite one final time — all 214 tests must pass | 30 min | 🔲 |
| 5.20 | Test every tab on a physical device — fresh install, go through onboarding, no crashes | 1–2 hrs | 🔲 |
| 5.21 | Test StoreKit in sandbox — full purchase flow: monthly, annual, cancel, restore | 1 hr | 🔲 |
| 5.22 | Confirm mic permission flow — deny then grant, both paths handled gracefully | 30 min | 🔲 |
| 5.23 | Submit for App Store Review — set pricing, select build, fill metadata, click Submit | 1 hr | 🔲 |

---

## Time Summary

| Phase | Description | Est. Hours |
|---|---|---|
| Phase 1 | Cleanup & Architecture | 6–9 hrs |
| Phase 2 | Design System | 18–25 hrs |
| Phase 3 | Onboarding | 6–8 hrs |
| Phase 4 | Monetization | 10–13 hrs |
| Phase 5 | App Store Submission | 18–25 hrs |
| **Total** | | **58–80 hrs** |

---

## How to Use This Roadmap

Work through phases in order — each phase builds on the last. Do not jump to Phase 4 (Monetization) until Phases 1–3 are solid.

For each task, open Claude Code and say:

> "Help me complete task [number]: [task name]"

Then share the relevant Swift files. Every task on this list is Claude-assisted — you do not need to write code from scratch.

Mark tasks complete by changing `🔲` to `✅` as you go. When a full phase is done, that's a real milestone worth acknowledging.

**You already built the hard parts. Everything here is execution, not invention.**
