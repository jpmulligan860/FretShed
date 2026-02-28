# FretShed — Strategy & Content Guide

> **This file is owned by Claude.ai.** It is read during Claude.ai planning/strategy/content sessions. Claude Code reads it for reference but does not edit it. For the technical development guide, see `CLAUDE.md`.

## Start of Every Claude.ai Session
1. Read this file fully
2. Read ROADMAP_STRATEGY.md to know current strategy task status
3. Read TEAM_OF_EXPERTS.md if invoking any expert personas
4. Confirm which task or research question we are working on before diving in

---

## Project Overview

FretShed is an iOS guitar fretboard training app that helps guitarists memorize notes across the fretboard. It targets adult hobbyist guitarists (beginner to intermediate) who play acoustic steel-string or electric guitar across rock, blues, classic rock, folk, singer-songwriter, metal, and genre-agnostic fundamentals.

**Core differentiators (defensible):**
1. **Environment calibration** — No competitor calibrates to the user's room noise, guitar signal, and input source
2. **Bayesian adaptive mastery scoring** — Per-position scoring dynamically weights quiz selection toward weak spots
3. **All-in-one practice toolkit** — Tuner + metronome + drone built into the same app

**App Store name:** FretShed: Guitar Fretboard
**Subtitle:** Learn Every Fretboard Note
**Pricing:** Freemium — $4.99/mo · $29.99/yr · $49.99 lifetime (14-day trial on monthly/annual)

---

## Positioning & Competitive Landscape

### Approved Positioning Language
- ✅ "The fretboard trainer that actually gets your notes right"
- ✅ "Calibrated to your guitar. Adaptive to your progress."
- ✅ "The smartest way to master your fretboard"
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

## Business Model (Finalized)

| Decision | Value |
|---|---|
| **Free tier modes** | Full Fretboard + Single String only |
| **Free tier fretboard** | Strings 4–6, frets 0–7 |
| **Free tier features** | Audio detection ON, adaptive ON, full stats, built-in mic calibration |
| **Premium modes** | All 7 focus modes |
| **Premium fretboard** | All 6 strings, all frets |
| **Premium extras** | USB/BT calibration profiles, unlimited history |
| **Pricing** | $4.99/mo · $29.99/yr · $49.99 lifetime |
| **Trial** | 14-day free trial on monthly and annual |
| **Analytics** | TelemetryDeck (privacy-focused, no PII) |

---

## Distribution & Marketing Assets

- **Email list:** 3,500 targeted guitarists (via partner's guitar lesson website)
- **Partner relationship:** Guitar lesson website owner — coordinate launch timing and messaging
- **Pre-launch email sequence:** 4-week drip planned (teaser → feature deep-dive → early access → launch day)

---

## Content & Education Strategy

### Research Initiative: "The Best Way to Learn Guitar"

**Goal:** Determine the optimal sequence for learning major guitar components, grounded in evidence from music institutions, experienced educators, and learning science research. Use findings to:
1. Position FretShed within the broader guitar learning journey (where does fretboard memorization fit?)
2. Create educational content that establishes credibility and drives downloads
3. Inform future feature development (what should FretShed teach next?)
4. Provide marketing ammunition (data-backed learning claims)

**Key questions to answer:**
- What are the major components of learning guitar? (technique, theory, ear training, fretboard knowledge, rhythm, repertoire, etc.)
- What order should they be learned? Is there a validated sequence?
- What do major music schools and guitar educators say about sequencing?
- Where do they agree and disagree?
- Are there ways to combine concepts for more efficient learning?
- Where does fretboard note memorization sit in the priority order?
- What does cognitive/learning science say about optimal guitar practice?

**Expert team for this research:** Peter Graves, Theo Marsh, Leo Sandoval, Irene Novak, Trent Holloway, Fiona Beckett (Content & Strategy Team). See TEAM_OF_EXPERTS.md for full personas.

**Status:** Not started — expert team assembled, research questions defined.

---

## Educational Content Pipeline

*Planned content that bridges the research initiative with marketing:*

| Content Type | Purpose | Status |
|---|---|---|
| "The Best Way to Learn Guitar" (long-form) | Cornerstone educational content, SEO, credibility | 🔲 |
| "Where Fretboard Memorization Fits" (article) | Positions FretShed in the learning journey | 🔲 |
| "Why Most Guitar Apps Get Detection Wrong" (article) | Competitor differentiation, calibration story | 🔲 |
| Pre-launch email sequence (4 emails) | Converts email list to downloads | 🔲 |
| App Store description | ASO, conversion from browse to download | 🔲 |
| Explainer video scripts | App Store preview, social media, website | 🔲 |

---

## Reference Documents (in Claude.ai Project)

- `TEAM_OF_EXPERTS.md` — All 20 expert personas organized by team (Technical + Content & Strategy)
- `FretShed_Competitive_Analysis.md` — Full competitive landscape with feature matrix and positioning
- `ADAPTIVE_LEARNING.md` — How the Bayesian mastery system works (plain language)
- `AUDIO_CALIBRATION.md` — How the calibration system works (plain language)
- `PITCH_DETECTION.md` — How the pitch detection pipeline works (plain language)
- `FRETSHED-DESIGN-PROMPT.md` — Woodshop design system specification
- `CLAUDE.md` — Technical development guide (Claude Code's domain — read only)
- `ROADMAP.md` — Technical build roadmap (Claude Code's domain — read only)
- `ROADMAP_STRATEGY.md` — Strategy/content roadmap (Claude.ai's domain)

---

## Action Items from Competitive Analysis
- [x] Update onboarding subtitle in code: "The guitar trainer that actually gets your notes right."
- [ ] When writing App Store description: lead with calibration + adaptive learning, NOT "only app that listens"
- [ ] When creating App Store screenshots: feature the calibration flow as a key differentiator

---

## File Ownership Protocol

To prevent sync conflicts between Claude.ai and Claude Code:

| File | Owned by | Other interface |
|---|---|---|
| `CLAUDE.md` | Claude Code | Claude.ai reads, never edits |
| `CLAUDE_STRATEGY.md` | Claude.ai | Claude Code reads, never edits |
| `ROADMAP.md` | Claude Code | Claude.ai reads, never edits |
| `ROADMAP_STRATEGY.md` | Claude.ai | Claude Code reads, never edits |
| `TEAM_OF_EXPERTS.md` | Either (rarely changes) | Both read, coordinate edits |

**Rule:** If you need to update a file owned by the other interface, note the needed change in your own file under "Cross-file update needed" and flag it to the user for manual sync.
