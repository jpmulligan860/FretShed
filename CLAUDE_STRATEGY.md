# FretShed — Strategy & Content Guide

> **This file is owned by Claude.ai.** It is read during Claude.ai planning/strategy/content sessions. Claude Code reads it for reference but does not edit it. For the technical development guide, see `CLAUDE.md`.

## Start of Every Claude.ai Session

> **Do not read files from Project Knowledge for living documents.**
> All living documents are fetched live from GitHub at session start.
> See SYNC_PROTOCOL.md for the full file ownership list.

1. **Confirm the bootstrap prompt was used** — the session should have started with a `sync_prompt.sh` output containing raw GitHub URLs. If it was not, ask John to run `./sync_prompt.sh` and paste the output before proceeding.

2. **Read all fetched files in order:**
   - CLAUDE_STRATEGY.md (this file — from GitHub)
   - ROADMAP_STRATEGY.md
   - CLAUDE.md
   - ROADMAP.md
   - BUGLOG.md
   - SYNC_PROTOCOL.md

3. **Scan all Sync Ledgers** — find any 🔲 Pending entries in CLAUDE.md, ROADMAP.md, CLAUDE_STRATEGY.md, and ROADMAP_STRATEGY.md. These represent the authoritative current state and override any inline content. Do not proceed until all pending entries are absorbed.

4. **Read TEAM_OF_EXPERTS.md** (from Project Knowledge) if invoking expert personas this session.

5. **Confirm active task** — state which ROADMAP_STRATEGY.md task we're working on before diving in.

> **Why fetching from GitHub matters:** Claude Code commits changes to living docs
> at session end and pushes to GitHub. Claude.ai Project Knowledge cannot auto-update.
> Fetching from GitHub ensures you're reasoning from the actual current state —
> not a stale cached version that may be days or weeks behind.

---

## Session End Protocol

**Every Claude.ai session must end with this checklist. Do not consider a session complete until all steps are done.**

**Trigger phrases:** "wrap up", "end session", "that's it for today", "good night", "goodnight", "gn", or similar.

1. **Update CLAUDE_STRATEGY.md** — If any business decisions, positioning changes, or product decisions were made this session, update the relevant sections (Current State, Business Model, Positioning, etc.).

2. **Update ROADMAP_STRATEGY.md** — Mark any completed strategy tasks as ✅ and any in-progress tasks as 🚧.

3. **Update Sync Ledger in ROADMAP_STRATEGY.md** — If any changes were made that Claude Code needs to apply to CLAUDE.md or ROADMAP.md, log them as 🔲 Pending inbound entries with a paste-ready prompt.

4. **Check for Claude Code actions needed** — Did this session produce any decisions that require code changes? If yes, generate a paste-ready Claude Code prompt and tell John explicitly.

5. **Memory check** — Did this session change anything that should update userMemories? (pricing decisions, feature decisions, major pivots, positioning changes). If yes, use the memory tool to update before closing.

6. **Print a session summary** — A brief recap of:
   - What was accomplished
   - What decisions were locked
   - What the next task is

7. **Output full file content** for any Claude.ai-owned files changed this session (CLAUDE_STRATEGY.md and/or ROADMAP_STRATEGY.md) — wrapped in a clearly labeled code block so Claude Code can write them to disk.

8. **Generate John's explicit action list** — Always end every session with this block, even if nothing is needed:

```
📋 WHAT YOU NEED TO DO:

PASTE INTO CLAUDE CODE (if needed):
- [paste-ready prompt including git pull, file writes, commit, and push — or "nothing"]

PROJECT KNOWLEDGE: Re-upload only if a static file changed:
- [list files, or "nothing — living docs are on GitHub"]

NOTES:
- [anything else John needs to know]
```

> **Rule:** Never leave a session without generating this block. John should never have to guess what to do.
> The "DOWNLOAD & REPLACE IN CLAUDE.AI PROJECT" instruction is retired — living docs are never uploaded manually.

---

## Current State (as of Mar 2026)

**Phases 1–4 (code) are complete.** App Store submission (Phase 5) is next. One pre-submission code task added: phase gate for free tier (Phase 3/4 paywall triggers).

| Layer | Status |
|---|---|
| Core app (Phases 1–3) | ✅ Complete |
| Smart Practice Redesign (SP.1–SP.8) | ✅ Complete — 4-phase curriculum (Foundation→Expansion→Connection→Fluency), musical note grouping, phase-aware messaging |
| Session Insight Engine (INS.1–INS.5) | ✅ Complete |
| Spacing Gate & Smart Review (SG.1–SG.9) | ✅ Complete — 3-checkpoint spaced repetition, always-on review block |
| Phase 4 Monetization (EntitlementManager, PaywallView, StoreKit 2) | ✅ Code complete — App Store Connect business setup (4.2–4.4) still pending |
| Phase gate for free tier (Phase 3/4 triggers paywall) | 🔲 Not yet coded — pre-submission task |
| App Store description | 🚧 v6 draft in progress |
| Phase 5 (App Store Submission) | 🔲 Not started |
| Test count | 448 (0 failures) |

---

## Project Overview

FretShed is an iOS guitar fretboard training app that helps guitarists memorize notes across the fretboard. It targets adult hobbyist guitarists (beginner to intermediate) who play acoustic steel-string or electric guitar across rock, blues, classic rock, folk, singer-songwriter, metal, and genre-agnostic fundamentals.

**Core differentiators (defensible):**
1. **Environment calibration** — No competitor calibrates to the user's room noise, guitar signal, and input source
2. **Bayesian adaptive mastery scoring** — Per-position scoring dynamically weights quiz selection toward weak spots
3. **4-phase learning curriculum** — Foundation → Expansion → Connection → Fluency; musically grouped note sets, phase-aware messaging, stacked learning (theory by osmosis)
4. **Spacing Gate mastery model** — Notes must prove retention across multiple calendar days before earning "mastered" status; prevents the fluency illusion
5. **All-in-one practice toolkit** — Tuner + metronome + drone built into the same app

**App Store name:** FretShed: Guitar Fretboard
**Subtitle:** Learn Every Fretboard Note
**Pricing:** Freemium — $4.99/mo · $29.99/yr · $49.99 lifetime (14-day trial on monthly/annual)

---

## Positioning & Competitive Landscape

### Approved Positioning Language
- ✅ "The fretboard trainer that actually gets your notes right"
- ✅ "Calibrated to your guitar. Adaptive to your progress."
- ✅ "The smartest way to master your fretboard"
- ✅ "An adaptive learning system that happens to use your real guitar" (positioning lead — not a detection feature)
- ❌ NEVER: "The only app that listens to you play" or any "only" claim about audio detection

### Key Competitors (Fretboard-Focused + Audio Detection)
| App | Audio | Calibration | Adaptive Learning | Heatmap | Tools |
|---|---|---|---|---|---|
| **Fret Pro** | ✅ | ❌ | Spaced repetition | ❌ | ❌ |
| **Solo** (Tom Quayle) | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Guitar Blast** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Fretonomy** | ✅ | ❌ | ❌ | ✅ | Basic |
| **FretShed** | ✅ | ✅ | ✅ (Bayesian) | ✅ | ✅ |

Full analysis: `FretShed_Competitive_Analysis.md` in project files.

---

## Business Model (Finalized — Locked Mar 21, 2026)

| Decision | Value |
|---|---|
| **Free tier modes** | Full Fretboard + Single String only |
| **Free tier fretboard** | Strings 4–6, frets 0–12 |
| **Free tier phases** | Phases 1 & 2 only (natural notes + sharps/flats, single string) |
| **Free tier gate** | String/fret gate + phase gate. Phase 3 (Connection) and Phase 4 (Fluency) trigger paywall for free users |
| **Premium modes** | All 7 focus modes |
| **Premium fretboard** | All 6 strings, all frets |
| **Premium phases** | All 4 phases (Phases 3 & 4 unlocked) |
| **Premium extras** | Multiple saved named calibration profiles (USB/wired interface; single profile free), unlimited history |
| **Pricing** | $4.99/mo · $29.99/yr · $49.99 lifetime |
| **Trial** | 14-day free trial on monthly and annual |
| **Analytics** | TelemetryDeck (privacy-focused, no PII) |

> **Note:** Bluetooth audio input was removed from FretShed entirely due to latency issues. There are no BT calibration profiles, no BT as a premium feature, and no BT references anywhere in the app. USB/wired interface calibration is free; multiple saved named calibration profiles is the premium upsell.

**Free tier value:** All 12 notes (naturals + accidentals) on strings 4–6, frets 0–12. Approximately half the fretboard. Complete Phases 1 and 2 learning experience. Natural conversion trigger: Phase 3 reveals cross-string triad shapes that extend onto locked strings.

**4 phases (post SP.8 resequencing — implemented order):**
| Phase | Name | Content | Tier |
|---|---|---|---|
| **Phase 1** | Foundation | Natural notes · Single string · All 6 strings sequentially | Free (strings 4–6 only) |
| **Phase 2** | Expansion | Sharps & flats · Single string · Same string-by-string progression | Free (strings 4–6 only) |
| **Phase 3** | Connection | Cross-string · Natural notes · Triad shapes, octave pairs | 🔒 Premium |
| **Phase 4** | Fluency | Full fretboard · All notes · Chord-tone patterns | 🔒 Premium |

---

## Distribution & Marketing Assets

- **Email list:** 3,500 targeted guitarists (via partner's guitar lesson website) — not yet activated
- **Partner relationship:** Guitar lesson website owner — coordinate launch timing and messaging
- **Pre-launch email sequence:** 4-week drip planned (teaser → feature deep-dive → early access → launch day) — see ROADMAP_STRATEGY Phase S6B

---

## Content & Education Strategy

### Research Initiative: "The Best Way to Learn Guitar"

**Goal:** Determine the optimal sequence for learning major guitar components, grounded in evidence from music institutions, experienced educators, and learning science research.

**Expert team:** Peter Graves, Theo Marsh, Leo Sandoval, Irene Novak, Trent Holloway, Fiona Beckett. See TEAM_OF_EXPERTS.md for full personas.

**Status:** Phase S0 complete March 2026. Phases S1–S5 not yet started. See ROADMAP_STRATEGY.md.

---

## Educational Content Pipeline

| Content Type | Purpose | Status |
|---|---|---|
| "The Best Way to Learn Guitar" (long-form) | Cornerstone educational content, SEO, credibility | 🔲 |
| "Where Fretboard Memorization Fits" (article) | Positions FretShed in the learning journey | 🔲 |
| "Why Most Guitar Apps Get Detection Wrong" (article) | Competitor differentiation, calibration story | 🔲 |
| "How FretShed Teaches Notes Differently" (article) | Phase system + stacked learning explained | 🔲 |
| Pre-launch email sequence (4 emails) | Converts email list to downloads | 🔲 |
| App Store description | ASO, conversion from browse to download | 🚧 v6 draft in progress |
| Explainer video scripts | App Store preview, social media, website | 🔲 |

---

## Reference Documents

**Fetched live from GitHub each session (living docs):**
- `CLAUDE.md` — Technical development guide (Claude Code's domain — read only)
- `ROADMAP.md` — Technical build roadmap (Claude Code's domain — read only)
- `ROADMAP_STRATEGY.md` — Strategy/content roadmap (Claude.ai's domain)
- `BUGLOG.md` — Active bug log (Claude Code's domain — read only)
- `SYNC_PROTOCOL.md` — Sync workflow reference

**In Claude.ai Project Knowledge (static reference docs):**
- `TEAM_OF_EXPERTS.md` — All expert personas organized by team
- `FretShed_Competitive_Analysis.md` — Full competitive landscape with feature matrix
- `AUDIO_CALIBRATION.md` — How the calibration system works (plain language)
- `FRETSHED-DESIGN-PROMPT.md` — Woodshop design system specification

---

## Action Items from Competitive Analysis
- [x] Update onboarding subtitle in code: "The guitar trainer that actually gets your notes right."
- [ ] When writing App Store description: lead with Smart Practice + adaptive learning, NOT "only app that listens"
- [ ] When creating App Store screenshots: feature the calibration flow as a key differentiator

---

## File Ownership Protocol

| File | Owned by | Other interface |
|---|---|---|
| `CLAUDE.md` | Claude Code | Claude.ai reads, never edits |
| `CLAUDE_STRATEGY.md` | Claude.ai | Claude Code reads, never edits |
| `ROADMAP.md` | Claude Code | Claude.ai reads, never edits |
| `ROADMAP_STRATEGY.md` | Claude.ai | Claude Code reads, never edits |
| `TEAM_OF_EXPERTS.md` | Either (rarely changes) | Both read, coordinate edits |

**Rule:** If you need to update a file owned by the other interface, log the needed change in ROADMAP_STRATEGY.md Sync Ledger and generate a paste-ready Claude Code prompt for John.
