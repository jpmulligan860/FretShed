# FretShed — Sync Protocol

> **This file is shared by both Claude.ai and Claude Code.**
> It lives in the GitHub repo and is fetched — never manually uploaded.
> Neither side edits it without coordinating with John.

---

## Core Principle

**GitHub is the single source of truth. Claude Code is the only git writer. Claude.ai is read-only.**

```
Claude.ai → reads from GitHub (raw URLs)
          → proposes changes → packages them in handoff prompt
Claude Code → applies changes → commits → pushes to GitHub
```

John is no longer the transport layer for living documents.

---

## File Ownership

| File | Owned by | Writer | How it gets to GitHub |
|---|---|---|---|
| `CLAUDE.md` | Claude Code | Claude Code | Direct commit |
| `ROADMAP.md` | Claude Code | Claude Code | Direct commit |
| `CLAUDE_STRATEGY.md` | Claude.ai | Claude Code | Via handoff prompt at session end |
| `ROADMAP_STRATEGY.md` | Claude.ai | Claude Code | Via handoff prompt at session end |
| `SYNC_PROTOCOL.md` | Shared | Either (coordinate) | Direct commit |
| `TEAM_OF_EXPERTS.md` | Either | Either (coordinate) | Direct commit |
| `BUGLOG.md` | Claude Code | Claude Code | Direct commit |

> **Why Claude Code writes Claude.ai-owned files:**
> Claude.ai cannot commit to git. When Claude.ai updates CLAUDE_STRATEGY.md or
> ROADMAP_STRATEGY.md, it outputs the full updated file content at session end.
> Claude Code receives this via the handoff prompt and commits it.

---

## Claude.ai Project Knowledge

The following files are **removed from Claude.ai Project Knowledge** and fetched live from GitHub instead.

| File | Why removed |
|---|---|
| `CLAUDE.md` | Changes frequently; GitHub is always current |
| `ROADMAP.md` | Changes frequently; GitHub is always current |
| `CLAUDE_STRATEGY.md` | Changes frequently; GitHub is always current |
| `ROADMAP_STRATEGY.md` | Changes frequently; GitHub is always current |
| `BUGLOG.md` | Changes frequently; GitHub is always current |
| `SYNC_PROTOCOL.md` | Rarely changes; GitHub fetch is sufficient |

The following files **stay in Claude.ai Project Knowledge** (rarely change):

| File | Why kept |
|---|---|
| `TEAM_OF_EXPERTS.md` | Rarely changes; acceptable as static reference |
| `FretShed_Competitive_Analysis.md` | Rarely changes |
| `FRETSHED-DESIGN-PROMPT.md` | Rarely changes |
| `AUDIO_CALIBRATION.md` | Rarely changes |
| `FretShed_Competitive_Marketing_Report_v2.docx` | Static |
| `FretShed_Marketing_Report_v3.docx` | Static |
| `FretShed_Community_Research_Report.docx` | Static |
| `FretShed_Smart_Practice_Spec_v2.docx` | Static |

> **Rule:** If a file in Project Knowledge changes meaningfully, delete it and re-upload.
> But living documents never need re-uploading — they're always fetched from GitHub.

---

## Session Start: Claude.ai

**Replace manual file uploads with the bootstrap script.**

1. Run `./sync_prompt.sh` from project root (or `./sync_prompt.sh | pbcopy` to auto-copy)
2. Paste the output at the start of the Claude.ai session
3. Claude.ai fetches all living docs from GitHub raw URLs
4. Claude.ai confirms sync status before any work begins

No file uploads required.

---

## Session Start: Claude Code

Add `git pull` as the first line of every Claude Code session prompt.

---

## Session End: Claude.ai

At session end (triggered by "goodnight", "gn", "wrap up", etc.):

1. **Update ROADMAP_STRATEGY.md** — mark tasks ✅/🚧, log sync ledger entries
2. **Update CLAUDE_STRATEGY.md** — capture any business/product decisions made this session
3. **Check Sync Ledger** — are there pending outbound items Claude Code needs to apply?
4. **Output full file content** for any Claude.ai-owned files that changed this session (CLAUDE_STRATEGY.md and/or ROADMAP_STRATEGY.md) — wrapped in a clearly labeled code block
5. **Generate paste-ready Claude Code prompt** (see format below) that includes:
   - `git pull` first
   - Write the full content of any changed Claude.ai-owned files
   - Apply any Sync Ledger items to CLAUDE.md or ROADMAP.md
   - Commit and push all changes with a descriptive message
6. **Memory check** — use memory tool if any decisions warrant updating userMemories
7. **Session summary** — what was accomplished, decisions locked, next task
8. **Print WHAT YOU NEED TO DO block** (see format below)

### WHAT YOU NEED TO DO block format

```
📋 WHAT YOU NEED TO DO:

PASTE INTO CLAUDE CODE:
[paste-ready prompt, or "nothing"]

PROJECT KNOWLEDGE: Re-upload if changed this session:
[list files, or "nothing — living docs are on GitHub"]

NOTES:
[anything else John needs to know]
```

> **Key change from old protocol:** The "DOWNLOAD & REPLACE IN CLAUDE.AI PROJECT" line
> is removed. Living docs are never uploaded. Only static reference files ever need
> re-uploading to Project Knowledge.

---

## Session End: Claude Code

At session end:

1. **Commit all changes** — including any Claude.ai-owned files received via handoff prompt
2. **Push to GitHub:**
   ```bash
   git add -A && git commit -m "sync: [brief summary of session work]" && git push
   ```
3. **Update Sync Ledger** in CLAUDE.md and ROADMAP.md — log outbound changes Claude.ai needs
4. **Generate sync report** for Claude.ai if there are pending items

---

## The "Sync Me" Command

When John says **"sync me"** to either interface:

### Claude.ai responds:

```
📋 SYNC REPORT — Claude.ai

OUTBOUND (Claude Code needs to apply to CLAUDE.md / ROADMAP.md):
- [ ] [list pending Sync Ledger items, or "none"]

INBOUND (changes Claude Code made that I've absorbed from GitHub):
- [ ] [list, or "none — fetched at session start"]

PASTE INTO CLAUDE CODE (if needed):
> "[paste-ready prompt]"
```

### Claude Code responds:

```
📋 SYNC REPORT — Claude Code

OUTBOUND (Claude.ai needs to know about):
- [ ] [list pending Sync Ledger items, or "none"]

INBOUND (Claude.ai changes to apply):
- [ ] [list, or "none"]

COMMIT STATUS: [pushed / unpushed changes]
```

---

## Sync Ledger Format

Each owned file maintains a Sync Ledger at the bottom:

```markdown
## Sync Ledger

### Outbound (changes the other side needs)
| Date | What Changed | Target | Status |
|---|---|---|---|
| 2026-03-23 | Updated Phase 4 tasks | Claude.ai to note | 🔲 Pending |

### Inbound (changes requested by the other side)
| Date | Change Requested | Source | Status |
|---|---|---|---|
| 2026-03-23 | Update Task 4.5 status | ROADMAP_STRATEGY.md | ✅ Applied |
```

**Status values:** 🔲 Pending · ✅ Applied

---

## Paste-Ready Claude Code Prompt Format (from Claude.ai session end)

```
git pull

# Write updated Claude.ai-owned files
# [FILE: CLAUDE_STRATEGY.md]
cat > CLAUDE_STRATEGY.md << 'ENDOFFILE'
[full file content here]
ENDOFFILE

# [FILE: ROADMAP_STRATEGY.md]
cat > ROADMAP_STRATEGY.md << 'ENDOFFILE'
[full file content here]
ENDOFFILE

# Apply Sync Ledger items to Claude Code-owned files (if any):
# [list specific changes to CLAUDE.md or ROADMAP.md]

git add -A && git commit -m "sync: [session summary from Claude.ai]" && git push
```

---

## Quick Reference

| Scenario | Action |
|---|---|
| Starting a Claude.ai session | Run `./sync_prompt.sh`, paste output |
| Starting a Claude Code session | Include `git pull` at top of prompt |
| Claude.ai changes CLAUDE_STRATEGY.md | Output full file content → Claude Code writes + commits |
| Claude.ai changes ROADMAP_STRATEGY.md | Output full file content → Claude Code writes + commits |
| Claude Code changes CLAUDE.md or ROADMAP.md | Commit + push → Claude.ai fetches fresh next session |
| Static Project Knowledge file changes | Delete from Project Knowledge → re-upload |
| Mid-session file changed by Claude Code | Ask Claude.ai to re-fetch the raw URL |
