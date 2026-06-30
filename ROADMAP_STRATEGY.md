# FretShed — Strategy & Content Roadmap

> **This file is owned by Claude.ai.** It tracks strategy, research, content, and marketing tasks. For the technical build roadmap, see `ROADMAP.md` (owned by Claude Code).
>
> **Status key:** ✅ Done · 🔲 Not started · 🚧 In progress

---

## Phase S0 — Fretboard Learning Research & Smart Practice Redesign

**Goal:** Research how guitarists actually learn fretboard notes, evaluate FretShed's Smart Practice engine against evidence, and produce a redesign specification grounded in pedagogy, cognitive science, and competitor analysis.

**Expert team:** Gavin Fretwell (guitar pedagogy), Leo Sandoval (learning science), Peter Graves (curriculum design), Theo Marsh (music theory)

**Status: ✅ Complete (March 15, 2026)**

| # | Task | Expert(s) | Status |
|---|---|---|---|
| S0.1 | Deep web research: guitar fretboard learning methods, pedagogical consensus | Gavin, Peter | ✅ |
| S0.2 | Research: spaced repetition, interleaving, ZPD, chunking, elaborative encoding | Leo | ✅ |
| S0.3 | Research: competitor learning progression approaches (Fretonomy, Solo, Fretboard Learning) | All | ✅ |
| S0.4 | Research: adaptive learning system design (Duolingo Birdbrain, desirable difficulty) | Leo, Peter | ✅ |
| S0.5 | Diagnosis: why Smart Practice feels random (4 root causes identified) | All | ✅ |
| S0.6 | Design: 4-phase learning system (Foundation → Expansion → Connection → Fluency) — phases resequenced in SP.8 | All | ✅ |
| S0.7 | Design: musical note grouping algorithm (stacked learning — scale fragments, triads, chord-tone patterns) | Theo, Gavin | ✅ |
| S0.8 | Design: templated messaging system with dynamic variables | Peter, Leo | ✅ |
| S0.9 | Design: cold start logic per onboarding baseline level | Peter, Gavin | ✅ |
| S0.10 | Design: edge cases (phase regression, grace threshold, struggling users, free tier ceiling) | All | ✅ |
| S0.11 | Lock 15 design decisions with founder review | All | ✅ |
| S0.12 | Produce v2 design specification document | All | ✅ |
| S0.13 | Produce Claude Code implementation prompt (6-phase plan) | All | ✅ |

**Deliverables:**
- `FretShed_Smart_Practice_Spec_v2.docx` — Full specification (in Claude.ai project files)
- `SMART_PRACTICE_REDESIGN_PROMPT.md` — Claude Code implementation prompt (in Claude.ai project files + delivered to user)
- `FretShed_Learning_Research_Report.docx` — Original research report v1 (superseded by v2 spec)

**Implementation:** Complete. SP.1–SP.8 and SG.1–SG.9 (Spacing Gate) shipped. Test count 448 (0 failures).

---

## Phase S1 — Research: How to Learn Guitar (Broader)

**Goal:** Determine the optimal sequence for learning major guitar components, grounded in institutional curricula, educator consensus, and learning science research. Builds on Phase S0 fretboard-specific findings.

**Expert team:** Peter Graves, Theo Marsh, Leo Sandoval, Irene Novak, Trent Holloway, Fiona Beckett

**Note:** Phase S0 completed the fretboard memorization research. Phase S1 extends to the broader guitar learning journey (technique, theory, ear training, rhythm, repertoire, etc.).

| # | Task | Expert(s) | Est. | Status |
|---|---|---|---|---|
| S1.1 | Define the major components of learning guitar (taxonomy) | Peter Graves, Trent Holloway | 1 hr | 🔲 |
| S1.2 | Research institutional curricula sequencing (Berklee, GIT/MI, RCM, Trinity) | Peter Graves | 2 hrs | 🔲 |
| S1.3 | Research major online educator sequencing (JustinGuitar, Guitar Tricks, Pickup Music, etc.) | Peter Graves, Grant Ellison | 2 hrs | 🔲 |
| S1.4 | Map learning science principles to guitar practice (spaced repetition, interleaving, testing effect) | Leo Sandoval | 2 hrs | ✅ (covered in S0) |
| S1.5 | Identify where fretboard memorization fits in the learning journey | Fiona Beckett, Peter Graves, Theo Marsh | 1 hr | ✅ (covered in S0) |
| S1.6 | Analyze how theory and fretboard knowledge connect on guitar | Theo Marsh, Fiona Beckett | 1 hr | ✅ (covered in S0) |
| S1.7 | Identify opportunities to combine concepts for efficiency | Irene Novak, Leo Sandoval, Bianca Torres | 1 hr | ✅ (stacked learning design in S0) |
| S1.8 | Reality-check proposed sequence with teaching experience | Trent Holloway | 1 hr | 🔲 |
| S1.9 | Synthesize findings into a recommended learning sequence | All Content Team | 2 hrs | 🔲 |
| S1.10 | Document areas of consensus vs. disagreement with recommendations | All Content Team | 1 hr | 🔲 |

---

## Phase S2 — Memory & Motor Skill Integration

**Goal:** Understand how fretboard memorization interacts with motor skill development and cognitive retention, to inform both FretShed features and educational content.

**Expert team:** Mason Albright, Bianca Torres, Fiona Beckett, Leo Sandoval

**Note:** Phase S0 research covered active recall, elaborative encoding, and chunking as they relate to fretboard memorization. Phase S2 extends to motor skill integration specifically.

| # | Task | Expert(s) | Est. | Status |
|---|---|---|---|---|
| S2.1 | Map the stages of fretboard memorization (recognition → recall → automaticity) | Mason Albright, Fiona Beckett | 1 hr | 🔲 |
| S2.2 | Analyze how audio-based practice (FretShed) builds motor skills vs. tap mode | Bianca Torres, Mason Albright | 1 hr | 🔲 |
| S2.3 | Identify memory strategies most effective for fretboard learning | Mason Albright, Leo Sandoval | 1 hr | ✅ (covered in S0) |
| S2.4 | Research the knowledge-execution gap: knowing notes vs. playing them fluently | Bianca Torres, Fiona Beckett | 1 hr | 🔲 |
| S2.5 | Recommendations for FretShed practice patterns that build both memory and motor skill | All Phase S2 experts | 1 hr | 🔲 |

---

## Phase S3 — Content Development

**Goal:** Create educational content that establishes FretShed's credibility and drives downloads.

**Expert team:** Carmen Reeves, Grant Ellison, Cora Langston (Technical Team)

| # | Task | Expert(s) | Est. | Status |
|---|---|---|---|---|
| S3.1 | Write "The Best Way to Learn Guitar" cornerstone article | Carmen Reeves + research findings | 3-4 hrs | 🔲 |
| S3.2 | Write "Where Fretboard Memorization Fits in Your Guitar Journey" | Carmen Reeves, Fiona Beckett | 2 hrs | 🔲 |
| S3.3 | Write "Why Most Guitar Apps Get Detection Wrong" | Carmen Reeves | 2 hrs | 🔲 |
| S3.4 | Write "How FretShed Teaches Notes Differently" (phase system + stacked learning) | Carmen Reeves, Peter Graves | 2 hrs | 🔲 |
| S3.5 | Draft App Store description using educational positioning + phase system messaging | Carmen Reeves, Cora Langston, Mona Prescott | 1-2 hrs | 🚧 v3 (~2,150 chars) — awaiting final approval before keyword research |
| S3.6 | Draft pre-launch email sequence (4 emails) | Carmen Reeves, Lars Engström, Cora Langston | 2-3 hrs | 🔲 |
| S3.7 | Draft explainer video scripts (App Store preview, social, website) | Carmen Reeves, Grant Ellison | 2-3 hrs | 🔲 |

---

## Phase S4 — Marketing & Launch Positioning

**Goal:** Translate research and content into launch-ready marketing assets and strategy.

**Expert team:** Carmen Reeves, Grant Ellison, Lars Engström, Mona Prescott

| # | Task | Expert(s) | Est. | Status |
|---|---|---|---|---|
| S4.1 | Finalize FretShed positioning statement (internal) — include phase system as differentiator | Carmen Reeves, Grant Ellison | 1 hr | 🔲 |
| S4.2 | Define key marketing messages (3-5 core claims with evidence) | Carmen Reeves, Grant Ellison | 1 hr | 🔲 |
| S4.3 | Plan community outreach strategy (Reddit, YouTube, forums) | Grant Ellison, Lars Engström | 1-2 hrs | 🔲 |
| S4.4 | Identify potential influencer/educator partners | Grant Ellison | 1 hr | 🔲 |
| S4.5 | Coordinate launch plan with email list partner | Lars Engström | 1 hr | 🔲 |
| S4.6 | Screenshot benefit text strategy (education-focused, show phase progression) | Carmen Reeves, Uma Chen (Technical Team) | 1 hr | 🔲 |

---

## Phase S5 — Future Feature Research

**Goal:** Based on research findings, identify what FretShed should teach next (post-MVP).

| # | Task | Expert(s) | Est. | Status |
|---|---|---|---|---|
| S5.1 | Identify natural "next step" features after fretboard memorization | Peter Graves, Theo Marsh, Irene Novak | 1 hr | 🔲 |
| S5.2 | Evaluate interval training as a feature (connects memorization to theory) | Theo Marsh, Fiona Beckett | 1 hr | 🔲 |
| S5.3 | Evaluate scale position training (applies note knowledge to scales) | Theo Marsh, Peter Graves | 1 hr | 🔲 |
| S5.4 | Evaluate chord-tone training (applies note knowledge to chord construction) | Theo Marsh, Peter Graves | 1 hr | 🔲 |
| S5.5 | Prioritize post-MVP features based on learning sequence research | Irene Novak, Mona Prescott (Technical Team) | 1 hr | 🔲 |

---

## Phase S6 — Launch Execution

**Goal:** Execute the go-to-market plan in parallel with App Store submission (ROADMAP.md Phase 5). Activate the 3,500-person email list, prepare the website, and coordinate community outreach.

**Expert team:** Lars Engström (launch coordination), Carmen Reeves (content), Grant Ellison (community), Cora Langston (copy)

### S6A — Website Readiness

| # | Task | Expert(s) | Est. | Status |
|---|---|---|---|---|
| S6A.1 | Complete fretshed.com support page (`fretshed.com/support`) — WPForms contact form (required by Apple for App Store submission; coordinates with ROADMAP.md 5.7) | Cora Langston | 30 min | 🔲 |
| S6A.2 | Publish privacy policy at `fretshed.com/privacy` (coordinates with ROADMAP.md 5.6) | | 30 min | 🔲 |
| S6A.3 | Review and complete remaining website pages — homepage, features, about | Carmen Reeves, Cora Langston | 2-3 hrs | 🔲 |
| S6A.4 | Add App Store download link to website on launch day | | 15 min | 🔲 |

### S6B — Email List Activation (MailerLite)

| # | Task | Expert(s) | Est. | Status |
|---|---|---|---|---|
| S6B.1 | Set up MailerLite account — Growing Business plan (~$25–39/mo for 3,500 subscribers) | Lars Engström | 30 min | 🔲 |
| S6B.2 | Import email list from partner — verify deliverability, warm up sender domain | Lars Engström | 1 hr | 🔲 |
| S6B.3 | Draft email 1 (Teaser) — "Something is coming for guitar players" | Carmen Reeves, Cora Langston | 1 hr | 🔲 |
| S6B.4 | Draft email 2 (Feature Deep-Dive) — the calibration + adaptive learning story | Carmen Reeves | 1 hr | 🔲 |
| S6B.5 | Draft email 3 (Early Access / Beta invite) — TestFlight link, 3-month free premium offer | Lars Engström, Carmen Reeves | 1 hr | 🔲 |
| S6B.6 | Draft email 4 (Launch Day) — App Store link, limited-time offer if any | Carmen Reeves, Lars Engström | 1 hr | 🔲 |
| S6B.7 | Schedule and send drip sequence — 4 emails over 4 weeks leading up to launch | Lars Engström | 30 min | 🔲 |

### S6C — App Store Submission Support

| # | Task | Expert(s) | Est. | Status |
|---|---|---|---|---|
| S6C.1 | Finalize App Store description (v3 → final) — approve and hand off to ROADMAP.md 5.12 | Cora Langston, Mona Prescott | 30 min | 🔲 |
| S6C.2 | Keyword research — 100-char keyword field strategy, title/subtitle optimization | Mona Prescott | 1 hr | 🔲 |
| S6C.3 | Screenshot benefit text copywriting — 1-line callout per screen (coordinates with 5.3) | Cora Langston, Carmen Reeves | 1 hr | 🔲 |

### S6D — Community Outreach

| # | Task | Expert(s) | Est. | Status |
|---|---|---|---|---|
| S6D.1 | Draft Reddit launch post — r/guitarlessons, r/learnguitar; lead with value not promotion | Grant Ellison, Carmen Reeves | 1 hr | 🔲 |
| S6D.2 | Identify YouTube guitar educator channels for outreach — 5–10 targets | Grant Ellison | 1 hr | 🔲 |
| S6D.3 | Draft outreach message for YouTube educators — personalized, non-spammy | Grant Ellison, Carmen Reeves | 1 hr | 🔲 |
| S6D.4 | Identify and engage relevant guitar forums and Facebook groups | Grant Ellison | 1 hr | 🔲 |

---

## Time Summary

| Phase | Description | Est. Hours | Status |
|---|---|---|---|
| Phase S0 | Fretboard Learning Research & Smart Practice Redesign | ~8 hrs | ✅ Complete |
| Phase S1 | Research: How to Learn Guitar (broader) | ~8 hrs (reduced — S0 covered 4 tasks) | 🔲 |
| Phase S2 | Memory & Motor Skill Integration | ~4 hrs (reduced — S0 covered 1 task) | 🔲 |
| Phase S3 | Content Development | 14-18 hrs | 🔲 |
| Phase S4 | Marketing & Launch Positioning | 5-7 hrs | 🔲 |
| Phase S5 | Future Feature Research | 5 hrs | 🔲 |
| Phase S6 | Launch Execution | 12-16 hrs | 🔲 |
| **Total** | | **~56-66 hrs** | |

---

## Cross-File Updates Needed

*When Claude.ai discovers something that needs to change in a Claude Code-owned file, log it here:*

| Date | Target File | Change Needed | Status |
|---|---|---|---|
| 2026-03-15 | ROADMAP.md | Add "Smart Practice Redesign" section (tasks SP.1–SP.6) between Session Insight Engine and Phase 4. Implementation prompt delivered. | ✅ Done (SP.1–SP.8 complete in ROADMAP.md) |
| 2026-03-15 | CLAUDE.md | After Smart Practice implementation is complete: add "Smart Practice Phase System" architecture section documenting LearningPhaseManager, NoteGroupingEngine, temporal decay, messaging architecture | ✅ Done (documented in CLAUDE.md) |

*Remind the user to apply these changes during their next Claude Code session.*

---

## Sync Ledger

> Mirrors the outbound section of CLAUDE.md's Sync Ledger. Claude.ai absorbs these entries and marks them resolved here.

### Inbound from Claude Code (absorbed into this file)
| Date | What Changed | Absorbed Into | Status |
|---|---|---|---|
| 2026-03-15 | Smart Practice Redesign (SP.1–SP.7) + Session Insight Engine (INS.1–INS.5) complete. Test count 398. Next: Phase 4. | CLAUDE_STRATEGY.md Current State section; S0 implementation note | ✅ Absorbed |
| 2026-03-16 | SP.8: Phase resequenced (Foundation→Expansion→Connection→Fluency), frets 0–12 required for all phase advancement, free-tier restrictions removed, 7 insight bugs fixed, test count 425. | CLAUDE_STRATEGY.md Current State + Business Model; S0.6 note | ✅ Absorbed |
| 2026-03-18 | Spacing Gate & Smart Review (SG.1–SG.9): 3-checkpoint spaced repetition, always-on review block, heatmap proficient=gold/mastered=green, Phase Roadmap on Journey tab, Woodshop font sweep, default session length=20. Test count 448. | CLAUDE_STRATEGY.md Current State + differentiators | ✅ Absorbed |
